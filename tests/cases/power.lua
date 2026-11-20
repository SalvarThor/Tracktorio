-- 1.4: power city (coal + water -> steam -> hidden generator -> player's pole network).
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local CITY = "tt-city-power"

--- Power city at {x+0.5, 0.5} (9x9: x-4..x+5, y -4..5), coal fed from the north,
--- water from an infinity pipe at the south connection, a pole east of it, and an optional
--- electric-energy-interface consumer drawing `demand_w` watts.
local function power_rig(x, demand_w)
  h.clear_area({ { x - 10, -12 }, { x + 16, 14 } })
  local city = h.place_city(CITY, { x + 0.5, 0.5 })
  h.feeder({ x + 0.5, -5.5 }, { x + 0.5, -4.5 }, defines.direction.north,
    { { name = "coal", count = 200 } })
  local pipe = h.create("infinity-pipe", { x + 0.5, 5.5 })
  pipe.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "exactly", temperature = 15 })
  h.create("small-electric-pole", { x + 5.5, 0.5 })
  local eei
  if demand_w then
    eei = h.create("electric-energy-interface", { x + 7, 1 })
    eei.power_production = 0
    eei.power_usage = demand_w / 60          -- J per tick
    eei.electric_buffer_size = demand_w      -- one second of demand
    eei.energy = 0
  end
  return city, eei
end

return {
  {
    name = "power: placing the power city adds a linked hidden generator",
    fn = function()
      local city = power_rig(500, nil)
      local gens = h.surface().find_entities_filtered({ name = "tt-power-generator", position = city.position, radius = 1 })
      assert_.equals(#gens, 1, "generator count")
      assert_.falsy(gens[1].destructible, "generator destructible")
      local links = city.get_fluid_box_linked_connections()
      assert_.truthy(links and #links >= 1, "no linked connection: " .. serpent.line(links))
    end,
  },
  {
    name = "power: the hidden generator cannot be selected, so the city is what you hover",
    fn = function()
      local box = prototypes.entity["tt-power-generator"].selection_box
      assert_.truthy(box.left_top.x == box.right_bottom.x and box.left_top.y == box.right_bottom.y,
        "generator has a selection box: " .. serpent.line(box))
      assert_.falsy(prototypes.entity["tt-power-generator"].selectable_in_game, "selectable_in_game")
    end,
  },
  {
    name = "power: delivers electricity to a consumer on the pole network",
    fn = function(ctx)
      local city, eei = power_rig(540, 1000000) -- 1 MW
      ---@cast eei LuaEntity
      ctx:wait(60 * 15, function()
        local before = city.products_finished
        assert_.truthy(before > 0, "power city never crafted")
        eei.energy = 0
        ctx:wait(60, function()
          -- one second of a 1 MW demand should be (nearly) met: buffer refilled
          assert_.truthy(eei.energy > 0.9 * 1000000, "consumer got " .. eei.energy .. " J in 1 s")
          ctx:wait(60 * 5, function()
            assert_.truthy(city.products_finished > before, "stopped crafting under load")
          end)
        end)
      end)
    end,
  },
  {
    name = "power: with no demand the steam buffer fills and the city stalls",
    fn = function(ctx)
      local city = power_rig(580, nil)
      ctx:wait_until(function() return h.status_name(city) == "full_output" end, 60 * 60, function()
        -- let the last craft settle into the generator's own buffer, then it must stay put
        ctx:wait(60 * 10, function()
          local made = city.products_finished
          ctx:wait(60 * 20, function()
            assert_.equals(city.products_finished, made, "kept burning coal with no demand")
            assert_.equals(h.status_name(city), "full_output")
          end)
        end)
      end)
    end,
  },
  {
    name = "power: starves without water",
    fn = function(ctx)
      h.clear_area({ { 610, -12 }, { 636, 14 } })
      local city = h.place_city(CITY, { 620.5, 0.5 })
      city.insert({ name = "coal", count = 10 })
      ctx:wait(60 * 5, function()
        assert_.equals(city.products_finished, 0, "crafted without water")
      end)
    end,
  },
  {
    name = "power: destroying the city removes its generator",
    fn = function(ctx)
      h.clear_area({ { 650, -12 }, { 676, 14 } })
      local city = h.place_city(CITY, { 660.5, 0.5 })
      local pos = city.position
      city.destroy()
      ctx:wait(2, function()
        local gens = h.surface().find_entities_filtered({ name = "tt-power-generator", position = pos, radius = 1 })
        assert_.equals(#gens, 0, "generator left behind")
      end)
    end,
  },
}
