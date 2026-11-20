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
