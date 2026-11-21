-- Throttle (PLAN 2.12): a hidden beacon inside every crafting city and the research complex,
-- holding hidden modules that each take 5% off speed and power draw together. Script
-- (scripts/throttle.lua) sets how many, so a city fed below its full rate runs steadily
-- at that rate instead of flat out and then idle. The beacon's supply area stays inside
-- the building: nothing outside it is slowed.
local config = require("shared.config")

local empty = { filename = "__core__/graphics/empty.png", width = 1, height = 1, priority = "extra-high" }

data:extend({
  { type = "module-category", name = config.THROTTLE_CATEGORY },
  {
    type = "module",
    name = config.THROTTLE_MODULE,
    icon = "__base__/graphics/icons/speed-module.png",
    hidden = true,
    hidden_in_factoriopedia = true,
    subgroup = "module",
    category = config.THROTTLE_CATEGORY,
    tier = 1,
    stack_size = 100,
    effect = { speed = -config.THROTTLE_STEP, consumption = -config.THROTTLE_STEP },
  },
  {
    type = "beacon",
    name = config.THROTTLE_BEACON,
    icon = "__base__/graphics/icons/beacon.png",
    hidden = true,
    hidden_in_factoriopedia = true,
    flags = {
      "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable", "not-upgradable",
      "no-copy-paste", "not-flammable", "not-repairable", "not-in-kill-statistics", "not-on-map",
      "not-selectable-in-game",
    },
    max_health = 10000,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    allowed_effects = { "speed", "consumption" },
    allowed_module_categories = { config.THROTTLE_CATEGORY },
    supply_area_distance = 1, -- reaches the city around it and nothing past its walls
    energy_source = { type = "void" },
    energy_usage = "1W",
    distribution_effectivity = 1,
    profile = { 1 },
    beacon_counter = "same_type",
    module_slots = config.THROTTLE_MAX_STEPS,
    graphics_set = { animation_list = {} },
    -- no module icons in alt mode
    icons_positioning = { { inventory_index = defines.inventory.beacon_modules, scale = 0, max_icons_per_row = 1,
      max_icon_rows = 0, shift = { 0, 0 }, separation_multiplier = 1, multi_row_initial_height_modifier = 0 } },
    radius_visualisation_picture = empty,
  },
})
