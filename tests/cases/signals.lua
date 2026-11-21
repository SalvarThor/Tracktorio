-- 2.11: city signal points. Two constant combinators in each city's door: stock and status,
-- and what the next tier still needs. Read here through a pole wired to them.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local city_defs = require("__tracktorio__/shared/city_defs")

local X = 44000
local RED = defines.wire_connector_id.circuit_red

--- A city at (x + 0.5, 0.5) with a medium pole 3 tiles below its tier 3 footprint (so it
--- survives upgrades), wired with red wire to the city's point of `kind`. Returns city, pole.
---@param name string
---@param x number
---@param kind "stock"|"construction"
local function wired_city(name, x, kind)
  h.clear_area({ { x - 12, -12 }, { x + 12, 16 } })
  local city = h.place_city(name, { x + 0.5, 0.5 })
  local pole = h.create("medium-electric-pole", { x + 0.5, 11.5 })
  local point = assert(remote.call("tt-city", "signal_points", city)[kind], "no " .. kind .. " point")
  assert(point.get_wire_connector(RED, true).connect_to(pole.get_wire_connector(RED, true), false),
    "could not wire the point to the pole")
  return city, pole
end

---@param pole LuaEntity
---@param type string
---@param name string
local function read(pole, type, name)
  local net = pole.get_circuit_network(RED)
  if not net then return 0 end
  return net.get_signal({ type = type, name = name, quality = type == "item" and "normal" or nil })
end

--- Rewrite every city's signals, then run `fn` a tick later (a combinator's output reaches
--- the network on the next tick).
---@param ctx table
---@param fn function
local function after_signals(ctx, fn)
  remote.call("tt-city", "signals_tick")
  ctx:wait(1, fn)
end

return {
  {
    name = "signal points: every city has a stock point in its door; a construction point below max tier",
    fn = function()
      local i = 0
      for _, def in ipairs(city_defs.list) do
        for tier = 1, #def.tiers do
          local name = city_defs.entity_name(def.name, tier)
          local x = X + i * 24
          i = i + 1
          h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
          local city = h.place_city(name, { x + 0.5, 0.5 })
          local points = remote.call("tt-city", "signal_points", city)
          local stock = assert(points.stock, name .. " has no stock point")
          assert_.equals(stock.name, "tt-signal-point")
          local e = h.edges(city)
          assert_.truthy(math.abs(stock.position.y - (e.bottom - 1)) < 0.01, name .. " stock point not on the south wall")
          assert_.truthy(math.abs(stock.position.x - city.position.x) <= 1, name .. " stock point not at the door")
          assert_.falsy(stock.operable, name .. " stock point is operable")
          assert_.falsy(stock.minable_flag, name .. " stock point is minable")
          assert_.truthy(stock.prototype.selectable_in_game, name .. " stock point is not selectable")
          if tier < #def.tiers then
            local c = assert(points.construction, name .. " has no construction point")
            assert_.equals(c.name, "tt-signal-point-construction")
            assert_.truthy(c.position.x ~= stock.position.x, name .. " points overlap")
          else
            assert_.falsy(points.construction, name .. " at max tier has a construction point")
          end
          city.destroy()
        end
      end
    end,
  },
  {
    name = "signal points: destroying a city removes them",
    fn = function(ctx)
      local x = X + 3000
      h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      local points = remote.call("tt-city", "signal_points", city)
      city.destroy()
      ctx:wait(2, function()
        assert_.falsy(points.stock.valid, "stock point left behind")
        assert_.falsy(points.construction.valid, "construction point left behind")
      end)
    end,
  },
  {
    name = "signals: the stock point sends what the city holds, starved status and tier",
    fn = function(ctx)
      local x = X + 3050
      local city, pole = wired_city("tt-city-iron-smelting", x, "stock")
      city.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-ore", count = 40 })
      city.get_inventory(defines.inventory.crafter_output).insert({ name = "iron-plate", count = 25 })
      ctx:wait(10, function()
        after_signals(ctx, function()
          assert_.equals(read(pole, "item", "iron-ore"), 40, "iron ore")
          -- the output port's loader holds a few plates itself
          local plates = city.get_inventory(defines.inventory.crafter_output).get_item_count("iron-plate")
          assert_.truthy(plates > 0, "no plates left in the city")
          assert_.equals(read(pole, "item", "iron-plate"), plates, "iron plates")
          assert_.equals(read(pole, "virtual", "signal-T"), 1, "tier")
          -- ore but no coal: starved
          assert_.equals(read(pole, "virtual", "tt-city-starved"), 1, "starved")
          assert_.equals(read(pole, "virtual", "tt-city-running"), 0, "running while starved")
        end)
      end)
    end,
  },
  {
    name = "signals: running and output full show on the stock point",
    fn = function(ctx)
      local x = X + 3100
      local city, pole = wired_city("tt-city-iron-smelting", x, "stock")
      local input = city.get_inventory(defines.inventory.crafter_input)
      input.insert({ name = "iron-ore", count = 50 })
      input.insert({ name = "coal", count = 50 })
      ctx:wait(30, function()
        after_signals(ctx, function()
          assert_.equals(read(pole, "virtual", "tt-city-running"), 1, "running (status " .. h.status_name(city) .. ")")
          city.get_inventory(defines.inventory.crafter_output).insert({ name = "iron-plate", count = 1000 })
          ctx:wait(400, function()
            after_signals(ctx, function()
              assert_.equals(read(pole, "virtual", "tt-city-output-full"), 1, "output full")
              assert_.equals(read(pole, "virtual", "tt-city-running"), 0, "running while full")
            end)
          end)
        end)
      end)
    end,
  },
  {
    name = "signals: a fluid city sends its fluids in whole units; an unpowered city says no power",
    fn = function(ctx)
      local x = X + 3150
      local city, pole = wired_city("tt-city-refinery", x, "stock")
      h.pipe_at(city, "water", "input", true)
      ctx:wait(60, function()
        after_signals(ctx, function()
          local water = city.get_fluid_count("water")
          assert_.truthy(water > 1, "no water reached the city")
          assert_.equals(read(pole, "fluid", "water"), math.floor(water), "water")
          assert_.equals(read(pole, "virtual", "tt-city-no-power"), 1, "no power")
        end)
      end)
    end,
  },
  {
    name = "signals: the construction point counts down as materials arrive, and wires follow the upgrade",
    fn = function(ctx)
      local x = X + 3200
      local city, pole = wired_city("tt-city-iron-smelting", x, "construction")
      local status = assert(remote.call("tt-city", "upgrade_status", city))
      local item, need = next(status.cost)
      assert(item, "no upgrade cost")
      after_signals(ctx, function()
        assert_.equals(read(pole, "item", item), need, "missing " .. item .. " before delivery")
        h.feed_port(city, item, 10)
        after_signals(ctx, function()
          assert_.equals(read(pole, "item", item), need - 10, "missing " .. item .. " after 10 arrived")
          -- wire the stock point too, then upgrade: both wires reach the new points
          local stock = remote.call("tt-city", "signal_points", city).stock
          stock.get_wire_connector(defines.wire_connector_id.circuit_green, true)
            .connect_to(pole.get_wire_connector(defines.wire_connector_id.circuit_green, true), false)
          local pos = city.position
          remote.call("tt-city", "port_fill", city, 1)
          remote.call("tt-city", "port_tick")
          local t2 = assert(h.city_at(pos))
          assert_.equals(t2.name, "tt-city-iron-smelting-t2")
          local points = remote.call("tt-city", "signal_points", t2)
          assert(points.construction and points.construction.valid, "no construction point at tier 2")
          local t3_cost = assert(remote.call("tt-city", "upgrade_status", t2)).cost
          local item3, need3 = next(t3_cost)
          assert(item3, "no tier 3 cost")
          after_signals(ctx, function()
            local net = pole.get_circuit_network(defines.wire_connector_id.circuit_green)
            local green = points.stock.get_wire_connector(defines.wire_connector_id.circuit_green, true)
            assert_.equals(green.connection_count, 1, "the green wire to the stock point was lost")
            assert(net, "no green network on the pole")
            assert_.equals(net.get_signal({ type = "virtual", name = "signal-T" }), 2, "tier after upgrade")
            assert_.equals(read(pole, "item", item3), need3, "the red wire to the construction point was lost")
          end)
        end)
      end)
    end,
  },
  {
    name = "signals: a train stop wired to a city takes its train limit from the city's stock",
    fn = function(ctx)
      local x = X + 3250
      local city, pole = wired_city("tt-city-iron-smelting", x, "stock")
      local stop = h.create("train-stop", { x + 5, 13 }, { direction = defines.direction.north })
      assert(stop.get_wire_connector(RED, true).connect_to(pole.get_wire_connector(RED, true), false), "could not wire the stop")
      local cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
      cb.set_trains_limit = true
      cb.trains_limit_signal = { type = "virtual", name = "signal-T" }
      after_signals(ctx, function()
        ctx:wait(1, function()
          assert_.equals(stop.trains_limit, 1, "limit from the tier signal")
          city.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-ore", count = 3 })
          cb.trains_limit_signal = { type = "item", name = "iron-ore", quality = "normal" }
          after_signals(ctx, function()
            ctx:wait(1, function()
              assert_.equals(stop.trains_limit, 3, "limit from the iron ore in the city")
            end)
          end)
        end)
      end)
    end,
  },
}
