-- 2.5: cities of the rocket chain. Each case: tier 1 rates (per second), power, and a real
-- run with infinity pipes (supply at the bottom, drain at the top) and items inserted.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local X = 9400

local CASES = {
  -- 2.5.2 chemistry
  { city = "tt-city-plastic", watts = 315e3,
    rates = { ["petroleum-gas"] = 30, coal = 1.5, ["plastic-bar"] = 3 },
    items = { coal = 50 }, supply = { [0] = "petroleum-gas" }, product = "plastic-bar" },
  { city = "tt-city-sulfur", watts = 105e3,
    rates = { ["petroleum-gas"] = 15, water = 15, sulfur = 1 },
    supply = { [-2] = "petroleum-gas", [2] = "water" }, product = "sulfur" },
  { city = "tt-city-sulfuric-acid", watts = 100e3,
    rates = { sulfur = 0.5, ["iron-plate"] = 0.1, water = 10, ["sulfuric-acid"] = 5 },
    items = { sulfur = 50, ["iron-plate"] = 10 }, supply = { [0] = "water" }, drain = { [0] = "sulfuric-acid" },
    product = "sulfuric-acid" },
  -- 2.5.3 electronics
  { city = "tt-city-advanced-circuits", watts = 1.35e6,
    rates = { ["electronic-circuit"] = 2, ["plastic-bar"] = 2, ["copper-plate"] = 2, ["advanced-circuit"] = 1 },
    items = { ["electronic-circuit"] = 20, ["plastic-bar"] = 20, ["copper-plate"] = 20 }, product = "advanced-circuit" },
  { city = "tt-city-processing-units", watts = 400e3,
    rates = { ["electronic-circuit"] = 4, ["advanced-circuit"] = 0.4, ["sulfuric-acid"] = 1, ["processing-unit"] = 0.2 },
    items = { ["electronic-circuit"] = 40, ["advanced-circuit"] = 4 }, supply = { [0] = "sulfuric-acid" },
    product = "processing-unit" },
  -- 2.5.4
  { city = "tt-city-low-density-structure", watts = 600e3,
    rates = { ["steel-plate"] = 0.4, ["copper-plate"] = 4, ["plastic-bar"] = 1, ["low-density-structure"] = 0.2 },
    items = { ["steel-plate"] = 10, ["copper-plate"] = 100, ["plastic-bar"] = 20 }, product = "low-density-structure" },
  -- 2.5.5
  { city = "tt-city-blue-science", watts = 960e3,
    rates = { ["steel-plate"] = 0.2, ["iron-plate"] = 0.8, ["advanced-circuit"] = 0.3, sulfur = 0.1, ["chemical-science-pack"] = 0.2 },
    items = { ["steel-plate"] = 10, ["iron-plate"] = 40, ["advanced-circuit"] = 15, sulfur = 5 }, product = "chemical-science-pack" },
}

--- Per-second amounts of every ingredient and product at the city's tier 1 speed.
local function rates(name)
  local p = prototypes.entity[name]
  local r = p.fixed_recipe
  local per_s = p.get_crafting_speed() / r.energy
  local out = {}
  for _, i in ipairs(r.ingredients) do out[i.name] = i.amount * per_s end
  for _, o in ipairs(r.products) do out[o.name] = o.amount * per_s end
  return out
end

local function pipe(pos, fluid, supply)
  local p = h.create("infinity-pipe", pos)
  p.set_infinity_pipe_filter({ name = fluid, percentage = supply and 1 or 0, mode = "exactly" })
end

local tests = {
  {
    name = "chain: tier 1 rates and power of the rocket chain cities",
    fn = function()
      for _, c in ipairs(CASES) do
        local got = rates(c.city)
        for name, want in pairs(c.rates) do
          assert_.truthy(got[name] and math.abs(got[name] - want) < 1e-6, c.city .. " " .. name .. ": " .. tostring(got[name]))
        end
        for name in pairs(got) do assert_.truthy(c.rates[name], c.city .. " has extra " .. name) end
        local w = prototypes.entity[c.city].get_max_energy_usage() * 60
        assert_.truthy(math.abs(w - c.watts) < 1000, c.city .. " draws " .. w)
        for tier = 2, 3 do assert_.truthy(prototypes.entity[c.city .. "-t" .. tier], c.city .. " tier " .. tier) end
      end
    end,
  },
}

tests[#tests + 1] = {
  -- Steel axe's research trigger is "craft 50 steel plates"; the steel city must count.
  name = "chain: steel made by a steel city completes the Steel axe research trigger",
  fn = function(ctx)
    local force = game.forces["player"]
    local axe, pre = force.technologies["steel-axe"], force.technologies["steel-processing"]
    local was = pre.researched
    pre.researched = true
    assert_.falsy(axe.researched, "steel axe already researched")
    local x = X - 40
    h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
    local city = h.place_city("tt-city-steel-t3", { x + 0.5, 0.5 })
    city.insert({ name = "iron-plate", count = 400 })
    h.test_power({ x + 8.5, 0.5 }, 8e6)
    local out = assert(city.get_inventory(defines.inventory.crafter_output))
    local t0 = game.tick
    ctx:wait_until(function()
      out.clear() -- keep the output from filling up
      city.insert({ name = "iron-plate", count = 100 }) -- and the input topped up
      return axe.researched or city.products_finished >= 70 or game.tick - t0 > 60 * 25
    end, 60 * 30, function()
      local made = city.products_finished
      local done = axe.researched
      axe.researched = false
      pre.researched = was
      -- earlier tests may already have made some of the 50 steel, so only the result counts
      assert_.truthy(done, "made " .. made .. " steel (" .. remote.call("tt-city", "info", city).status .. "); trigger not met")
    end)
  end,
}

for i, c in ipairs(CASES) do
  tests[#tests + 1] = {
    name = "chain: " .. c.city .. " makes " .. c.product .. " from its inputs on power",
    fn = function(ctx)
      local x = X + i * 40
      h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
      local city = h.place_city(c.city, { x + 0.5, 0.5 })
      for name, count in pairs(c.items or {}) do city.insert({ name = name, count = count }) end
      for dx, fluid in pairs(c.supply or {}) do pipe({ x + dx + 0.5, 5.5 }, fluid, true) end
      for dx, fluid in pairs(c.drain or {}) do pipe({ x + dx + 0.5, -4.5 }, fluid, false) end
      h.test_power({ x + 8.5, 0.5 }, 4e6)
      ctx:wait_until(function() return city.products_finished >= 1 end, 60 * 30, function()
        assert_.equals(remote.call("tt-city", "info", city).recipe.products[1].name, c.product)
      end)
    end,
  }
end

return tests
