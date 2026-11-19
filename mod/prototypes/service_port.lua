-- Service port (PLAN 2.3.3): a fixed 1x1 container beside each depot city that takes repair
-- packs only. Servicing (scripts/service.lua) uses the packs from it. Placed and protected by
-- script.
local config = require("shared.config")

local source = data.raw.container["iron-chest"]

data:extend({
  {
    type = "container",
    name = config.SERVICE_PORT,
    icon = source.icon,
    flags = {
      "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable",
      "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable", "not-in-kill-statistics",
    },
    minable = nil,
    max_health = 10000,
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    selection_priority = 60,
    map_color = { r = 0.3, g = 0.8, b = 0.9 },
    inventory_size = config.SERVICE_SLOTS,
    inventory_type = "with_filters_and_bar",
    picture = table.deepcopy(source.picture),
    impact_category = "metal",
  },
})
