-- 1.1: free logistics recipes, banned entities, hand-crafting restriction, start research.
local assert_ = require("__tracktorio-tests__/assert")

local FREE = { "rail", "locomotive", "cargo-wagon", "fluid-wagon", "train-stop", "rail-signal",
  "inserter", "transport-belt", "iron-chest", "pipe", "pump",
  "small-electric-pole", "big-electric-pole", "electric-mining-drill", "decider-combinator",
  "radar" } -- user, playtest 2.15.10
local BANNED = { "stone-furnace", "assembling-machine-1", "oil-refinery", "chemical-plant", "boiler",
  "steam-engine", "solar-panel", "car", "tank", "spidertron",
  "logistic-robot", "roboport", "requester-chest", "lab", "rocket-silo", "foundry", "recycler",
  "offshore-pump" } -- 2.9.2: water comes only from water cities
-- construction robots left this list on 2026-11-21 (user: personal construction robots,
-- tests/cases/start_kit.lua)
-- Unlocked at start (SPEC MVP starting research).
local START_ENABLED = { "rail", "locomotive", "cargo-wagon", "fluid-wagon", "train-stop", "rail-signal",
  "rail-chain-signal", "inserter", "burner-inserter", "transport-belt", "underground-belt",
  "splitter", "pipe", "pipe-to-ground", "pump", "small-electric-pole",
  "medium-electric-pole", "big-electric-pole", "burner-mining-drill", "electric-mining-drill" }
-- Free but research-gated: not unlocked at start.
local GATED = { "arithmetic-combinator", "fast-inserter", "fast-transport-belt", "rail-ramp", "pumpjack", "radar" }

local function player() return assert(game.players[1], "no player") end

return {
  {
    name = "restrictions: free recipes have no ingredients and the free category",
    fn = function()
      for _, name in ipairs(FREE) do
        local r = prototypes.recipe[name]
        assert_.truthy(r, "missing recipe " .. name)
        assert_.equals(#r.ingredients, 0, name .. " ingredients")
        assert_.equals(r.categories[1], "tt-free", name .. " category")
      end
    end,
  },
  {
    name = "restrictions: banned recipes are hidden and disabled for the player",
    fn = function()
      local force = game.forces["player"]
      for _, name in ipairs(BANNED) do
        local r = prototypes.recipe[name]
        assert_.truthy(r, "missing recipe " .. name)
        assert_.truthy(r.hidden, name .. " not hidden")
        assert_.falsy(force.recipes[name].enabled, name .. " enabled")
      end
    end,
  },
  {
    name = "restrictions: no technology unlocks a banned recipe",
    fn = function()
      local banned = {}
      for _, n in ipairs(BANNED) do banned[n] = true end
      for tname, tech in pairs(prototypes.technology) do
        for _, e in ipairs(tech.effects) do
          if e.type == "unlock-recipe" then
            assert_.falsy(banned[e.recipe], tname .. " unlocks " .. tostring(e.recipe))
          end
        end
      end
    end,
  },
  {
    name = "restrictions: character crafts only the free category",
    fn = function()
      local cats = prototypes.entity["character"].crafting_categories
      local list = {}
      for k in pairs(cats or {}) do list[#list + 1] = k end
      assert_.equals(#list, 1, "category count")
      assert_.equals(list[1], "tt-free")
    end,
  },
  {
    name = "restrictions: start research unlocks the MVP set, gated items stay locked",
    fn = function()
      local force = game.forces["player"]
      for _, name in ipairs(START_ENABLED) do
        assert_.truthy(force.recipes[name].enabled, name .. " not unlocked at start")
      end
      for _, name in ipairs(GATED) do
        assert_.falsy(force.recipes[name].enabled, name .. " unlocked at start")
      end
    end,
  },
  {
    name = "restrictions: player hand-crafts a free item from an empty inventory",
    fn = function(ctx)
      local p = player()
      p.get_main_inventory().clear()
      assert_.truthy(p.get_craftable_count("rail") > 0, "rail not craftable")
      assert_.equals(p.begin_crafting({ recipe = "rail", count = 10 }), 10)
      ctx:wait_until(function() return p.crafting_queue_size == 0 end, 60, function()
        local per_craft = prototypes.recipe["rail"].products[1].amount
        assert_.equals(p.get_item_count("rail"), 10 * per_craft)
      end)
    end,
  },
  {
    name = "restrictions: player cannot hand-craft intermediates even with ingredients",
    fn = function()
      local p = player()
      p.insert({ name = "iron-plate", count = 100 })
      assert_.equals(p.get_craftable_count("iron-gear-wheel"), 0)
      assert_.truthy(p.get_craftable_count("iron-chest") > 0, "free iron-chest should still be craftable")
      p.get_main_inventory().clear()
    end,
  },
  {
    name = "restrictions: the crafting menu shows only free recipes",
    fn = function()
      for _, name in ipairs({ "iron-gear-wheel", "electronic-circuit", "gun-turret", "stone-wall" }) do
        assert_.truthy(prototypes.recipe[name].hidden_from_player_crafting, name .. " shown in crafting menu")
      end
      for _, name in ipairs(FREE) do
        assert_.falsy(prototypes.recipe[name].hidden_from_player_crafting, name .. " hidden from crafting menu")
      end
    end,
  },
  {
    name = "restrictions: planets and platforms technologies are hidden",
    fn = function()
      for _, name in ipairs({ "space-platform", "planet-discovery-vulcanus" }) do
        local t = prototypes.technology[name]
        assert_.truthy(t and t.hidden, name .. " not hidden")
      end
      -- 2.15.5: Rocket silo stays, and gives the rocket silo city alone
      local silo = prototypes.technology["rocket-silo"]
      assert_.falsy(silo.hidden, "rocket-silo hidden")
      assert_.equals(#silo.effects, 1, "rocket-silo effects")
      assert_.equals(silo.effects[1].recipe, "tt-build-tt-city-rocket-silo")
    end,
  },
  {
    -- 2.6.2: hiding a tech whose only unlocks were banned cut everything behind it
    name = "restrictions: a tech hidden for giving only banned things doesn't cut the tree",
    fn = function()
      -- 2.15.5: Advanced material processing unlocks electric smelting now; Solar energy
      -- (the solar panel) is one that gives nothing left
      assert_.truthy(prototypes.technology["solar-energy"].hidden, "solar energy should be hidden (solar panel only)")
      assert_.falsy(prototypes.technology["advanced-material-processing"].hidden, "advanced material processing hidden")
      local planet = { "^planet%-discovery%-", "^space%-platform" }
      for name, t in pairs(prototypes.technology) do
        if not t.hidden then
          for pre, p in pairs(t.prerequisites) do
            local by_pattern = false
            for _, pat in ipairs(planet) do if string.find(pre, pat) then by_pattern = true end end
            assert_.truthy(not p.hidden or by_pattern, name .. " needs hidden " .. pre)
          end
        end
      end
      local concrete = prototypes.technology["concrete"]
      assert_.truthy(concrete.prerequisites["advanced-material-processing"], "concrete lost advanced material processing")
    end,
  },
}
