-- Construction port (PLAN 2.1.2): a fixed 1x1 container beside each upgradable city.
-- Script sets its slot filters to the materials the next tier still needs and counts and
-- removes deliveries every second. Placed and protected by scripts/ports.lua.
local config = require("shared.config")

local source = data.raw.container["steel-chest"]

data:extend({
  {
    -- Slot filter used when nothing more is needed (max tier, or the upgrade is complete).
    type = "item",
    name = config.PORT_CLOSED_ITEM,
    icon = "__core__/graphics/icons/mip/slot-item-in-hand.png",
    hidden = true,
    hidden_in_factoriopedia = true,
    stack_size = 1,
    auto_recycle = false,
  },
  {
    type = "container",
    name = config.PORT,
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
    map_color = { r = 0.9, g = 0.6, b = 0.1 },
    inventory_size = config.PORT_SLOTS,
    inventory_type = "with_filters_and_bar",
    picture = table.deepcopy(source.picture),
    impact_category = "metal",
  },
})
