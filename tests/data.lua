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
