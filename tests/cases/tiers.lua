-- 2.1.1: city tier prototypes (3 tiers, x1/x2/x4; electric smelting from tier 2).
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local defs = require("__tracktorio__/shared/city_defs")

--- Max output per minute of a city prototype's first product (labs: research speed).
local function max_per_min(entity_name)
  local p = prototypes.entity[entity_name]
  if p.type == "lab" then return p.get_researching_speed() end
  local r = assert(p.fixed_recipe, entity_name .. " has no fixed recipe")
  return r.products[1].amount * 60 * p.get_crafting_speed() / r.energy
end

local function has_ingredient(entity_name, item)
  for _, ing in ipairs(prototypes.entity[entity_name].fixed_recipe.ingredients) do
    if ing.name == item then return true end
  end
  return false
end

local function watts(entity_name)
  return prototypes.entity[entity_name].get_max_energy_usage() * 60
end

return {
  {
    name = "tiers: every city has tiers 1-3 at x1, x2, x4 of tier 1's output (the rocket silo has one)",
    fn = function()
      for _, def in ipairs(defs.list) do
        if def.kind == "silo" then
          assert_.equals(#def.tiers, 1, "the rocket silo has one tier (2.5.6)")
          goto continue
        end
        local base = max_per_min(defs.entity_name(def.name, 1))
        for tier, factor in ipairs({ 1, 2, 4 }) do
          local name = defs.entity_name(def.name, tier)
          assert_.truthy(prototypes.entity[name], "missing " .. name)
          local got = max_per_min(name)
          assert_.truthy(math.abs(got - base * factor) < 0.01, name .. " makes " .. got .. "/min")
        end
        ::continue::
      end
    end,
  },
  {
    name = "tiers: smelting is coal-fired at tier 1 and electric without coal from tier 2",
    fn = function()
      for _, n in ipairs({ "iron-smelting", "copper-smelting" }) do
        local t1, t2, t3 = defs.entity_name(n, 1), defs.entity_name(n, 2), defs.entity_name(n, 3)
        assert_.truthy(has_ingredient(t1, "coal"), t1 .. " lost coal")
        assert_.falsy(prototypes.entity[t1].electric_energy_source_prototype, t1 .. " is electric")
        for tier, mw in pairs({ [2] = 8.64, [3] = 17.28 }) do
          local name = tier == 2 and t2 or t3
          assert_.falsy(has_ingredient(name, "coal"), name .. " still needs coal")
          assert_.truthy(math.abs(watts(name) - mw * 1e6) < 1e4, name .. " draws " .. watts(name))
        end
      end
    end,
  },
  {
    name = "tiers: depot power scales with tier (0.84 / 1.68 / 3.36 MW)",
    fn = function()
      for tier, mw in ipairs({ 0.84, 1.68, 3.36 }) do
        local name = defs.entity_name("depot", tier)
        assert_.truthy(math.abs(watts(name) - mw * 1e6) < 1e4, name .. " draws " .. watts(name))
      end
    end,
  },
  {
    name = "tiers: upgrade costs never use the city's own product",
    fn = function()
      for _, def in ipairs(defs.list) do
        for tier = 2, #def.tiers do
          local t = def.tiers[tier]
          assert_.truthy(t.cost and #t.cost > 0, def.name .. " T" .. tier .. " has no cost")
          for _, p in ipairs(t.recipe and t.recipe.results or {}) do
            for _, c in ipairs(t.cost) do
              assert_.truthy(c.name ~= p.name, def.name .. " T" .. tier .. " costs its own " .. p.name)
            end
          end
        end
      end
    end,
  },
  {
    name = "tiers: a tier 2 power city delivers more than tier 1's 5.4 MW",
    fn = function(ctx)
      local x = 3300
      h.clear_area({ { x - 10, -12 }, { x + 16, 14 } })
      local city = h.place_city("tt-city-power-t2", { x + 0.5, 0.5 })
      city.insert({ name = "coal", count = 50 })
      local pipe = h.create("infinity-pipe", { x + 0.5, 5.5 })
      pipe.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "exactly", temperature = 15 })
      h.create("small-electric-pole", { x + 5.5, 0.5 })
      local eei = h.create("electric-energy-interface", { x + 7, 1 })
      eei.power_production = 0
      eei.power_usage = 8e6 / 60 -- 8 MW demand
      eei.electric_buffer_size = 8e6 / 60
      local gen = h.surface().find_entities_filtered({ name = "tt-power-generator-t2", position = city.position, radius = 1 })[1]
      assert_.truthy(gen, "no tier 2 generator")
      local total, ticks = 0, 0
      ctx:wait(60 * 10, function()
        -- average the generator output over the next second (measured at the source)
        local function sample()
          total, ticks = total + gen.energy_generated_last_tick, ticks + 1
          if ticks < 60 then ctx:wait(1, sample) else
            local mw = total / ticks * 60 / 1e6
            log(string.format("tt-tiers: power T2 delivered %.2f MW to an 8 MW demand", mw))
            assert_.truthy(mw > 7.5, "tier 2 delivered " .. mw .. " MW")
          end
        end
        sample()
      end)
    end,
  },
  {
    name = "tiers: an electric smelting city runs on power without coal",
    fn = function(ctx)
      local name = "tt-city-iron-smelting-t2"
      local city, _, cout = h.city_rig(name, 3400, { { name = "iron-ore", count = 100 } }, true)
      h.test_power({ 3407, 0 }, 10e6)
      ctx:wait_until(function() return cout.get_item_count("iron-plate") > 0 end, 60 * 30, function()
        assert_.truthy(city.products_finished > 0)
      end)
    end,
  },
}
