-- City radar (user, playtest 2.15.10): a hidden radar inside every city, so the player can
-- zoom in on any city from the map and watch it and its station live. It needs no power
-- (void energy), scans only the chunks near it (no long-range sector scans) and can't be
-- seen, selected or reached. scripts/cities.lua places it with the city and removes it with
-- the city. The vanilla radar is also free to build (config.FREE_ITEMS).
local config = require("shared.config")

local empty = { filename = "__core__/graphics/empty.png", width = 1, height = 1, priority = "extra-high",
  direction_count = 1 }

data:extend({
  {
    type = "radar",
    name = config.CITY_RADAR,
    icon = "__base__/graphics/icons/radar.png",
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
    selectable_in_game = false,
    energy_source = { type = "void" },
    energy_usage = "1W",
    energy_per_nearby_scan = "1J",
    energy_per_sector = "1J",
    max_distance_of_sector_revealed = 0,
    max_distance_of_nearby_sector_revealed = config.CITY_RADAR_CHUNKS,
    connects_to_other_radars = false,
    pictures = empty,
  },
})
