-- 2.9: the water city, the only source of water.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local WATER = "tt-city-water"
local X = 24000

local function info(city) return remote.call("tt-city", "info", city) end

--- A water city centred at (x + 0.5, 0.5), nothing else around it.
local function place(x)
  h.clear_area({ { x - 14, -14 }, { x + 14, 14 } })
  return h.place_city(WATER, { x + 0.5, 0.5 })
end

return {
  {
    -- 2.9.1
    name = "water: 600 water/s, no ingredients, no power",
    fn = function()
      local name = WATER
      local p = assert(prototypes.entity[name], name)
      local r = p.fixed_recipe
      assert_.equals(#r.ingredients, 0, name .. " ingredients")
      local per_s = p.get_crafting_speed() / r.energy
      assert_.equals(r.products[1].name, "water", name .. " product")
      assert_.equals(r.products[1].amount * per_s, 600, name .. " water/s")
      assert_.falsy(p.electric_energy_source_prototype, name .. " draws power")
    end,
  },
  {
    name = "water: with nothing but a pipe out of it, a water city makes 600 water/s",
    fn = function(ctx)
      local city = place(X)
      h.pipe_at(city, "water", "output", false)
      ctx:wait(60, function() -- settle
        local start = city.products_finished
        ctx:wait(600, function()
          local crafts = city.products_finished - start
          assert_.truthy(crafts >= 9 and crafts <= 11, "crafts in 10 s: " .. crafts)
          assert_.equals(info(city).status, "running")
        end)
      end)
    end,
  },
  {
    name = "water: undrained, it fills up and says output full (backpressure)",
    fn = function(ctx)
      local city = place(X + 60)
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 30, function()
        local made = city.products_finished
        ctx:wait(120, function()
          assert_.equals(city.products_finished, made, "kept making water while full")
        end)
      end)
    end,
  },
}
