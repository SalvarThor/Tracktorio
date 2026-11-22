-- 2.2.2: circuit, red science and green science cities.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local defs = require("__tracktorio__/shared/city_defs")

local function per_min(name)
  local p = prototypes.entity[name]
  local r = p.fixed_recipe
  return r.products[1].amount * 60 * p.get_crafting_speed() / r.energy
end

local function inputs_per_s(name)
  local p = prototypes.entity[name]
  local r = p.fixed_recipe
  local out = {}
  for _, ing in ipairs(r.ingredients) do out[ing.name] = ing.amount * p.get_crafting_speed() / r.energy end
  return out
end

-- Full rates of the vanilla equivalent; since 2.15.7 a city runs at defs.RATE of them.
local R = defs.RATE
local CASES = {
  { city = "tt-city-circuits", product = "electronic-circuit", per_min = 300, watts = 1.25e6,
    inputs = { ["iron-plate"] = 5, ["copper-plate"] = 7.5 } },
  { city = "tt-city-red-science", product = "automation-science-pack", per_min = 60, watts = 1.1e6,
    inputs = { ["iron-plate"] = 2, ["copper-plate"] = 1 } },
  { city = "tt-city-green-science", product = "logistic-science-pack", per_min = 60, watts = 1.5e6,
    inputs = { ["iron-plate"] = 4.5, ["electronic-circuit"] = 1 } },
  -- 2.5.1
  { city = "tt-city-steel", product = "steel-plate", per_min = 60, watts = 1.44e6,
    inputs = { ["iron-plate"] = 5 } },
}

local tests = {
  {
    name = "intermediates: rates, inputs and power match the vanilla equivalent",
    fn = function()
      for _, c in ipairs(CASES) do
        local p = prototypes.entity[c.city]
        assert_.equals(p.fixed_recipe.products[1].name, c.product, c.city)
        assert_.truthy(math.abs(per_min(c.city) - c.per_min * R) < 0.01, c.city .. " makes " .. per_min(c.city))
        local w = p.get_max_energy_usage() * 60
        assert_.truthy(math.abs(w - c.watts * R) < 1000, c.city .. " draws " .. w)
        local got = inputs_per_s(c.city)
        for item, rate in pairs(c.inputs) do
          assert_.truthy(math.abs((got[item] or 0) - rate * R) < 0.001, c.city .. " " .. item .. " " .. tostring(got[item]))
        end
        for item in pairs(got) do assert_.truthy(c.inputs[item], c.city .. " has extra input " .. item) end
      end
    end,
  },
}

for i, c in ipairs(CASES) do
  tests[#tests + 1] = {
    name = "intermediates: " .. c.city .. " turns its inputs into " .. c.product .. " on power",
    fn = function(ctx)
      local x = 4600 + i * 40
      local contents = {}
      for item in pairs(c.inputs) do contents[#contents + 1] = { name = item, count = 200 } end
      local city = h.city_rig(c.city, x, contents, true)
      ctx:wait(60 * 5, function()
        assert_.equals(city.products_finished, 0, "crafted without power")
        assert_.equals(remote.call("tt-city", "info", city).status == "no_power"
          or remote.call("tt-city", "info", city).status == "starved", true)
        h.test_power({ x + 8.5, 0.5 }, 4e6)
        ctx:wait_until(function() return city.products_finished > 0 end, 60 * 30, function()
          local out = remote.call("tt-city", "info", city)
          assert_.equals(out.recipe.products[1].name, c.product)
        end)
      end)
    end,
  }
end

return tests
