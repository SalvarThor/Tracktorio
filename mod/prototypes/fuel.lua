-- Locomotive fuel (SPEC: only depot cities make it). See DECISIONS.md A4.
local config = require("shared.config")

data:extend({
  { type = "fuel-category", name = config.LOCOMOTIVE_FUEL_CATEGORY },
  {
    type = "item",
    name = "tt-coal-fuel",
    -- coal with a flame badge (playtest 2.10: it read as plain coal on the depot's ports)
    icons = {
      { icon = "__base__/graphics/icons/coal.png", tint = { r = 1, g = 0.62, b = 0.3, a = 1 } },
      { icon = "__base__/graphics/icons/signal/signal-fire.png", scale = 0.3, shift = { 9, -9 }, floating = true },
    },
    subgroup = "raw-resource",
    order = "z[tt-coal-fuel]",
    stack_size = 50,
    auto_recycle = false, -- no recycling recipe: depot cities are the only source
    fuel_categories = { config.LOCOMOTIVE_FUEL_CATEGORY },
    fuel_value = "10MJ",
    fuel_acceleration_multiplier = 1,
    fuel_top_speed_multiplier = 1,
  },
  {
    -- Limp mode (SPEC MVP): script puts this straight into the burner of a locomotive whose
    -- fuel ran out, so it crawls instead of stopping dead. Never exists as an item stack.
    type = "item",
    name = config.LIMP_FUEL,
    icons = { { icon = "__base__/graphics/icons/coal.png", tint = { r = 0.5, g = 0.2, b = 0.2, a = 1 } } },
    hidden = true,
    hidden_in_factoriopedia = true,
    subgroup = "raw-resource",
    order = "z[tt-limp-fuel]",
    stack_size = 1,
    auto_recycle = false,
    fuel_categories = { config.LOCOMOTIVE_FUEL_CATEGORY },
    fuel_value = config.LIMP_FUEL_VALUE,
    fuel_acceleration_multiplier = config.LIMP_ACCELERATION,
    fuel_top_speed_multiplier = config.LIMP_TOP_SPEED,
  },
})

-- Fuel progression (PLAN 2.4.1): the vanilla solid fuel and rocket fuel also burn in
-- locomotives, with their vanilla stats. Only the solid and rocket fuel depots make them.
for _, name in ipairs(config.LOCOMOTIVE_FUELS) do
  local item = data.raw.item[name]
  if item and name ~= "tt-coal-fuel" then
    local cats = item.fuel_categories or { "chemical" }
    cats[#cats + 1] = config.LOCOMOTIVE_FUEL_CATEGORY
    item.fuel_categories = cats
  end
end

-- 2.6.4: uranium fuel cells burn in the nuclear power city and leave nothing behind (user:
-- no depleted cells to drain; reprocessing needs production science, which isn't in play).
-- A burner with no burnt-result slot would refuse fuel that has a burnt result.
data.raw.item["uranium-fuel-cell"].burnt_result = nil
