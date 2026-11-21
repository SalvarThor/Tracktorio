-- 2.11.5: locomotive tiers. Tier 1 is the vanilla locomotive; Mk2 and Mk3 have more power,
-- a higher top speed, better fuel use and slower wear. Free, unlocked by research.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local E = defines.direction.east
local X = 46000

local TIERS = {
  { name = "locomotive", power = 600e3, speed = 1.2, effectivity = 1, wear = 0.075 },
  { name = "tt-locomotive-2", power = 900e3, speed = 290 / 216, effectivity = 1.25, wear = 0.05 },
  { name = "tt-locomotive-3", power = 1.2e6, speed = 324 / 216, effectivity = 1.5, wear = 0.03 },
}

--- A 600-tile line at y with a locomotive of `name` on coal fuel, sent to the far end.
---@param y number
---@param name string
local function racer(y, name)
  h.clear_area({ { X - 4, y - 4 }, { X + 604, y + 4 } })
  local rails = {}
  for x = X, X + 600, 2 do rails[#rails + 1] = h.create("straight-rail", { x, y }, { direction = E }) end
  local loco = h.create(name, { X + 6, y }, { direction = E, raise_built = true })
  assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 10 })
  remote.call("tt-limp", "check_all") -- built empty, it limped: end that now for every racer alike
  local schedule = assert(loco.train).get_schedule()
  schedule.add_record({ rail = rails[#rails], temporary = true, wait_conditions = {} })
  schedule.go_to_station(1)
  return loco
end

return {
  {
    name = "locomotives: Mk2 and Mk3 have more power and fuel use than tier 1, and burn only locomotive fuel",
    fn = function()
      for _, t in ipairs(TIERS) do
        local p = assert(prototypes.entity[t.name], "no " .. t.name)
        assert_.truthy(math.abs(p.get_max_energy_usage() * 60 - t.power) < 1, t.name .. " power " .. p.get_max_energy_usage() * 60)
        local burner = assert(p.burner_prototype, t.name .. " has no burner")
        assert_.truthy(math.abs(burner.effectivity - t.effectivity) < 1e-6, t.name .. " effectivity " .. burner.effectivity)
        local cats = burner.fuel_categories
        assert_.truthy(cats["tt-locomotive"] and not cats["chemical"], t.name .. " fuel categories " .. serpent.line(cats))
      end
    end,
  },
  {
    name = "locomotives: Mk2 is red + green research, Mk3 red + green + blue; their recipes are free",
    fn = function()
      local force = game.forces["player"]
      local packs = { ["tt-locomotive-2"] = 2, ["tt-locomotive-3"] = 3 }
      for name, n in pairs(packs) do
        local tech = assert(prototypes.technology[name], "no technology " .. name)
        assert_.equals(#tech.research_unit_ingredients, n, name .. " packs")
        local unlocks = false
        for _, e in ipairs(tech.effects) do
          if e.type == "unlock-recipe" and e.recipe == name then unlocks = true end
        end
        assert_.truthy(unlocks, name .. " does not unlock its recipe")
        local recipe = prototypes.recipe[name]
        assert_.equals(#recipe.ingredients, 0, name .. " ingredients")
        assert_.equals(recipe.categories[1], "tt-free", name .. " category")
        assert_.falsy(force.recipes[name].enabled and not force.technologies[name].researched, name .. " is unlocked without research")
      end
      assert_.truthy(prototypes.technology["tt-locomotive-3"].prerequisites["tt-locomotive-2"], "Mk3 needs Mk2")
    end,
  },
  {
    name = "locomotives: wear per minute of driving is 7.5% / 5% / 3% by tier",
    fn = function()
      for i, t in ipairs(TIERS) do
        local y = 600 + i * 10
        h.clear_area({ { X - 4, y - 4 }, { X + 30, y + 4 } })
        for x = X, X + 24, 2 do h.create("straight-rail", { x, y }, { direction = E }) end
        local loco = h.create(t.name, { X + 6, y }, { direction = E, raise_built = true })
        remote.call("tt-reliability", "set", loco, 1)
        remote.call("tt-reliability", "wear", loco, 3600)
        local lost = 1 - remote.call("tt-reliability", "get", loco)
        assert_.truthy(math.abs(lost - t.wear) < 1e-6, t.name .. " lost " .. lost .. " in a minute")
      end
    end,
  },
  {
    name = "locomotives: a broken-down or fuel-empty Mk3 limps like the first locomotive",
    fn = function(ctx)
      local y = 660
      h.clear_area({ { X - 4, y - 4 }, { X + 64, y + 4 } })
      for x = X, X + 60, 2 do h.create("straight-rail", { x, y }, { direction = E }) end
      local loco = h.create("tt-locomotive-3", { X + 6, y }, { direction = E, raise_built = true })
      remote.call("tt-limp", "check_all")
      assert_.truthy(remote.call("tt-limp", "is_limping", loco), "a fuel-empty Mk3 does not limp")
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 5 })
      ctx:wait(70, function()
        assert_.falsy(remote.call("tt-limp", "is_limping", loco), "still limping after refuelling")
        remote.call("tt-reliability", "break_down", loco)
        remote.call("tt-limp", "check_all")
        assert_.truthy(remote.call("tt-reliability", "is_broken", loco), "not broken")
        assert_.truthy(remote.call("tt-limp", "is_limping", loco), "a broken Mk3 does not limp")
        local max = assert(loco.train).max_forward_speed
        assert_.truthy(math.abs(max - 324 / 216 * 0.25) < 0.001, "limp top speed " .. max)
      end)
    end,
  },
  {
    name = "locomotives: on the same line, Mk3 beats Mk2 beats tier 1 (speed after 4 s, top speed)",
    fn = function(ctx)
      local t3, t2, t1 = racer(700, "tt-locomotive-3"), racer(710, "tt-locomotive-2"), racer(720, "locomotive")
      ctx:wait(240, function() -- before the faster ones brake for the end of the line
        local function speed(l) return math.abs(assert(l.train).speed) end
        assert_.truthy(speed(t2) > speed(t1) and speed(t3) > speed(t2),
          string.format("speeds after 4 s: tier 1 %.3f, Mk2 %.3f, Mk3 %.3f", speed(t1), speed(t2), speed(t3)))
        for _, pair in ipairs({ { t1, TIERS[1] }, { t2, TIERS[2] }, { t3, TIERS[3] } }) do
          local max = assert(pair[1].train).max_forward_speed
          assert_.truthy(math.abs(max - pair[2].speed) < 0.001, pair[2].name .. " top speed " .. max)
        end
      end)
    end,
  },
}
