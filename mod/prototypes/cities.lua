-- City definitions (MVP). Rates are tuning values; see DECISIONS.md "1.3".
local blackbox = require("prototypes.blackbox")

local function item(name, amount) return { type = "item", name = name, amount = amount } end

local defs = {
  {
    -- 10 ore + 1 coal -> 10 plates per second at speed 1.5: cap 15 plates/s (one yellow belt).
    name = "iron-smelting",
    graphics = { type = "furnace", name = "electric-furnace" },
    crafting_speed = 1.5,
    recipe = {
      energy_required = 1,
      ingredients = { item("iron-ore", 10), item("coal", 1) },
      results = { item("iron-plate", 10) },
    },
    map_color = { r = 0.55, g = 0.6, b = 0.7 },
  },
  {
    name = "copper-smelting",
    graphics = { type = "furnace", name = "electric-furnace" },
    crafting_speed = 1.5,
    recipe = {
      energy_required = 1,
      ingredients = { item("copper-ore", 10), item("coal", 1) },
      results = { item("copper-plate", 10) },
    },
    map_color = { r = 0.8, g = 0.45, b = 0.25 },
  },
  {
    -- 2 coal -> 1 coal fuel per second at speed 2: cap 2 fuel/s.
    name = "depot",
    graphics = { type = "assembling-machine", name = "assembling-machine-3" },
    crafting_speed = 2,
    recipe = {
      energy_required = 1,
      ingredients = { item("coal", 2) },
      results = { item("tt-coal-fuel", 1) },
    },
    map_color = { r = 0.3, g = 0.3, b = 0.3 },
  },
}

-- Power city: coal + water -> steam into a hidden generator (scripts/cities.lua places and
-- links it). The generator only draws steam when the electric network demands power, so a
-- full steam buffer stalls the city. Steam at 165 C carries 30 kJ/unit (0.2 kJ/C above 15 C).
-- 1 coal + 150 water -> 150 steam per second at speed 1.2 = 180 steam/s = 5.4 MW cap.
local POWER_STEAM_TEMP = 165
defs[#defs + 1] = {
  name = "power",
  graphics = { type = "assembling-machine", name = "oil-refinery" },
  crafting_speed = 1.2,
  recipe = {
    energy_required = 1,
    ingredients = { item("coal", 1), { type = "fluid", name = "water", amount = 150 } },
    results = { { type = "fluid", name = "steam", amount = 150, temperature = POWER_STEAM_TEMP } },
  },
  fluid_boxes = {
    { production_type = "input", position = { 0, 4 }, direction = defines.direction.south, filter = "water" },
    { production_type = "output", linked_id = 1, filter = "steam" },
  },
  map_color = { r = 0.9, g = 0.85, b = 0.3 },
}

for _, def in ipairs(defs) do
  data:extend(blackbox.make_city(def))
end

-- The power city's hidden generator: same footprint, no collision, not selectable.
data:extend({
  {
    type = "generator",
    name = "tt-power-generator",
    icon = "__base__/graphics/icons/steam-engine.png",
    hidden = true,
    flags = { "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
      "not-selectable-in-game", "not-rotatable", "not-in-kill-statistics", "not-upgradable", "no-copy-paste" },
    max_health = 10000,
    collision_box = { { -4.4, -4.4 }, { 4.4, 4.4 } },
    -- no selection box: hovering/clicking must reach the city underneath (playtest 1.10)
    selectable_in_game = false,
    collision_mask = { layers = {} },
    effectivity = 1,
    fluid_usage_per_tick = 3, -- 180 steam/s
    maximum_temperature = POWER_STEAM_TEMP,
    fluid_box = {
      volume = 200,
      filter = "steam",
      production_type = "input",
      ---@diagnostic disable-next-line: missing-fields
      pipe_connections = { { connection_type = "linked", linked_connection_id = 1, flow_direction = "input" } },
    },
    energy_source = { type = "electric", usage_priority = "secondary-output" },
  },
})
