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

for _, def in ipairs(defs) do
  data:extend(blackbox.make_city(def))
end
