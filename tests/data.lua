-- Test-only prototypes, built with the mod's own city generator.
local blackbox = require("__tracktorio__/prototypes/blackbox")

data:extend(blackbox.make_city({
  name = "test",
  size = 5,
  graphics = { type = "assembling-machine", name = "assembling-machine-2" },
  crafting_speed = 1,
  recipe = {
    energy_required = 0.5,
    ingredients = {
      { type = "item", name = "iron-ore", amount = 1 },
      { type = "item", name = "coal", amount = 1 },
    },
    results = { { type = "item", name = "iron-plate", amount = 1 } },
  },
}))

-- 2.15.7: a loader at a quarter of yellow belt speed (3.75 items/s), for an exact slow feed.
local slow = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
slow.name = "tt-test-slow-loader"
slow.speed = data.raw["loader-1x1"]["loader-1x1"].speed / 4
slow.next_upgrade = nil
data:extend({ slow })

-- Playtest 2.15.10: another mod's inserter (free, as an inserter) and its furnace (not).
do
  local inserter = table.deepcopy(data.raw.inserter["inserter"])
  inserter.name = "tracktorio-test-modded-inserter"
  inserter.minable = { mining_time = 0.1, result = inserter.name }
  local furnace = table.deepcopy(data.raw.furnace["stone-furnace"])
  furnace.name = "tracktorio-test-modded-furnace"
  furnace.minable = { mining_time = 0.1, result = furnace.name }
  local function item(name)
    return { type = "item", name = name, icon = "__base__/graphics/icons/inserter.png", stack_size = 50, place_result = name }
  end
  local function recipe(name)
    return { type = "recipe", name = name, enabled = true, ingredients = { { type = "item", name = "iron-plate", amount = 2 } },
      results = { { type = "item", name = name, amount = 1 } } }
  end
  data:extend({ inserter, furnace, item(inserter.name), item(furnace.name), recipe(inserter.name), recipe(furnace.name) })
end
