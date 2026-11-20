-- 2.9: the water city, the only source of water.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local WATER = "tt-city-water"
local X = 24000

local function info(city) return remote.call("tt-city", "info", city) end

--- An infinity pipe at `pos` keeping `fluid` empty (a drain).
local function drain(pos, fluid)
  local p = h.create("infinity-pipe", pos)
  p.set_infinity_pipe_filter({ name = fluid, percentage = 0, mode = "exactly" })
  return p
end

--- A water city centred at (x + 0.5, 0.5), nothing else around it.
local function place(x)
  h.clear_area({ { x - 14, -14 }, { x + 14, 14 } })
  return h.place_city(WATER, { x + 0.5, 0.5 })
end

return {
  {
    -- 2.9.1
    name = "water: 600 / 1,200 / 2,400 water/s at tiers 1-3, no ingredients, no power",
    fn = function()
      for tier, want in ipairs({ 600, 1200, 2400 }) do
        local name = tier == 1 and WATER or (WATER .. "-t" .. tier)
        local p = assert(prototypes.entity[name], name)
        local r = p.fixed_recipe
        assert_.equals(#r.ingredients, 0, name .. " ingredients")
        local per_s = p.get_crafting_speed() / r.energy
        assert_.equals(r.products[1].name, "water", name .. " product")
        assert_.equals(r.products[1].amount * per_s, want, name .. " water/s")
        assert_.falsy(p.electric_energy_source_prototype, name .. " draws power")
      end
    end,
  },
  {
    name = "water: with nothing but a pipe out of it, a water city makes 600 water/s",
    fn = function(ctx)
      local city = place(X)
      drain({ X + 0.5, 5.5 }, "water")
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
  {
    name = "water: plates delivered to its port upgrade it to tier 2 (1,200/s)",
    fn = function()
      local city = place(X + 120)
      local pos = city.position
      h.feed_port(city, "iron-plate", 1000)
      h.feed_port(city, "copper-plate", 1000)
      local now = assert(h.city_at(pos))
      assert_.equals(now.name, WATER .. "-t2")
    end,
  },
}
