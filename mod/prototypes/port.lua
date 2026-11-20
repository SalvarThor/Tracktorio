-- Construction port (PLAN 2.1.2): a 1x1 container for each upgradable city. Script sets its
-- slot filters to the materials the next tier still needs and counts and removes deliveries
-- every second. Placed and protected by scripts/ports.lua. Since 2.10.6 it is hidden inside
-- the building, behind a belt port in the wall (scripts/belt_ports.lua) that feeds it.
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
      "not-on-map", "player-creation",
    },
    minable = nil,
    max_health = 10000,
    -- 2.10.6: hidden inside the building, fed by a belt port in the wall
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    hidden = true,
    hidden_in_factoriopedia = true,
    inventory_size = config.PORT_SLOTS,
    inventory_type = "with_filters_and_bar",
    picture = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    impact_category = "metal",
  },
})
