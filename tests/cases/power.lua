-- 1.4: power city (coal + water -> steam -> hidden generator -> player's pole network).
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local CITY = "tt-city-power"

--- Power city at {x+0.5, 0.5}, coal belted into its port, water from an infinity pipe at its
--- water port, a pole east of it, and an optional electric-energy-interface consumer
--- drawing `demand_w` watts.
local function power_rig(x, demand_w)
  h.clear_area({ { x - 12, -12 }, { x + 16, 14 } })
  local city = h.place_city(CITY, { x + 0.5, 0.5 })
  local e = h.edges(city)
  h.belt_in(city, { name = "coal", count = 200 })
  h.pipe_at(city, "water", "input", true)
  h.create("small-electric-pole", { e.right, 0.5 })
  local eei
  if demand_w then
    eei = h.create("electric-energy-interface", { e.right + 2, 1 })
    eei.power_production = 0
    eei.power_usage = demand_w / 60          -- J per tick
    eei.electric_buffer_size = demand_w      -- one second of demand
    eei.energy = 0
  end
  return city, eei
end

return {
  {
    -- user, playtest 2.15.10: 20 MW, not halved; one water city (300/s) feeds it
    name = "power: the coal power city makes 20 MW from 5 coal/s and 206 water/s",
    fn = function()
      local p = assert(prototypes.entity[CITY])
      local r = p.fixed_recipe
      local per_s = p.get_crafting_speed() / r.energy
      local coal, water = 0, 0
      for _, i in ipairs(r.ingredients) do
        if i.name == "coal" then coal = i.amount * per_s elseif i.name == "water" then water = i.amount * per_s end
      end
      assert_.truthy(math.abs(coal - 5) < 1e-6, "coal/s " .. coal)
      assert_.truthy(math.abs(water - 20e6 / 97e3) < 0.01 and water < 300, "water/s " .. water)
      assert_.equals(r.products[1].temperature, 500)
      local gen = assert(prototypes.entity["tt-power-generator"])
      local out = gen.get_max_energy_production() * 60
      assert_.truthy(math.abs(out - 20e6) < 1e3, "generator " .. out)
      -- the generator burns exactly what the city makes
      local steam = r.products[1].amount * per_s
      assert_.truthy(math.abs(steam * 97e3 - out) < 1e3, "steam made " .. steam .. "/s for a " .. out .. " W generator")
    end,
  },
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
