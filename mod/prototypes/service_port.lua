-- Service port (PLAN 2.3.3): a 1x1 container for each depot city that takes repair packs
-- only. Servicing (scripts/service.lua) uses the packs from it. Placed and protected by
-- script. Since 2.10.6 it is hidden inside the building, behind a belt port in the wall.
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
    inventory_size = config.SERVICE_SLOTS,
    inventory_type = "with_filters_and_bar",
    picture = { filename = "__core__/graphics/empty.png", width = 1, height = 1 },
    impact_category = "metal",
  },
})
