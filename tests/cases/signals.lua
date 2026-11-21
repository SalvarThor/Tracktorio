-- 2.11: city signal point. A constant combinator in each city's door: stock, status and
-- speed. Read here through a pole wired to it.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local city_defs = require("__tracktorio__/shared/city_defs")

local X = 44000
local RED = defines.wire_connector_id.circuit_red

--- A city at (x + 0.5, 0.5) with a medium pole below it, wired with red wire to the city's
--- point of `kind`. Returns city, pole.
---@param name string
---@param x number
---@param kind "stock"
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
    name = "signal points: every city has one stock point in its door",
    fn = function()
      for i, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local x = X + i * 24
        h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
        local city = h.place_city(name, { x + 0.5, 0.5 })
        local points = remote.call("tt-city", "signal_points", city)
        local stock = assert(points.stock, name .. " has no stock point")
        assert_.equals(table_size(points), 1, name .. " points")
        assert_.equals(stock.name, "tt-signal-point")
        local e = h.edges(city)
        assert_.truthy(math.abs(stock.position.y - (e.bottom - 1)) < 0.01, name .. " stock point not on the south wall")
        assert_.truthy(math.abs(stock.position.x - city.position.x) <= 1, name .. " stock point not at the door")
        assert_.falsy(stock.operable, name .. " stock point is operable")
        assert_.falsy(stock.minable_flag, name .. " stock point is minable")
        assert_.truthy(stock.prototype.selectable_in_game, name .. " stock point is not selectable")
        city.destroy()
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
      end)
    end,
  },
  {
    name = "signals: the stock point sends what the city holds and starved status",
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
    name = "signals: a train stop wired to a city takes its train limit from the city's stock",
    fn = function(ctx)
      local x = X + 3250
      local city, pole = wired_city("tt-city-iron-smelting", x, "stock")
      local stop = h.create("train-stop", { x + 5, 13 }, { direction = defines.direction.north })
      assert(stop.get_wire_connector(RED, true).connect_to(pole.get_wire_connector(RED, true), false), "could not wire the stop")
      local cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
      cb.set_trains_limit = true
      cb.trains_limit_signal = { type = "item", name = "iron-ore", quality = "normal" }
      city.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-ore", count = 1 })
      after_signals(ctx, function()
        ctx:wait(1, function()
          assert_.equals(stop.trains_limit, 1, "limit from 1 iron ore")
          city.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-ore", count = 2 })
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
