-- Locomotive fuel (SPEC: only depot cities make it). See DECISIONS.md A4.
local config = require("shared.config")

data:extend({
  { type = "fuel-category", name = config.LOCOMOTIVE_FUEL_CATEGORY },
  {
    type = "item",
    name = "tt-coal-fuel",
    icons = { { icon = "__base__/graphics/icons/coal.png", tint = { r = 1, g = 0.62, b = 0.3, a = 1 } } },
    subgroup = "raw-resource",
    order = "z[tt-coal-fuel]",
    stack_size = 50,
    auto_recycle = false, -- no recycling recipe: depot cities are the only source
    fuel_categories = { config.LOCOMOTIVE_FUEL_CATEGORY },
    fuel_value = "10MJ",
    fuel_acceleration_multiplier = 1,
    fuel_top_speed_multiplier = 1,
  },
})
