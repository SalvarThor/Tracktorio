-- City prototypes: one per city kind, from shared/city_defs.lua. Every city is the 12x12
-- Factorissimo building (2.15), the silo the vanilla 9x9.
local blackbox = require("prototypes.blackbox")
local defs = require("shared.city_defs")
local layout = require("shared.port_layout")

--- Fluid boxes: piped fluids at their port spots (shared/port_layout.lua), then hidden
--- linked boxes as defined.
---@param def table
---@param ports table[]
---@param size integer
local function fluid_boxes(def, ports, size)
  local boxes = {}
  for _, p in ipairs(ports) do
    if p.kind == "fluid" then
      local spot = layout.spot(p, size)
      local volume
      for _, b in ipairs(def.fluid_boxes or {}) do
        if b.filter == p.name and b.production_type == p.flow then volume = b.volume end
      end
      boxes[#boxes + 1] = { production_type = p.flow, filter = p.name, volume = volume,
        position = spot.inside, direction = spot.direction }
    end
  end
  for _, b in ipairs(def.fluid_boxes or {}) do
    if b.linked_id then boxes[#boxes + 1] = b end
  end
  return #boxes > 0 and boxes or nil
end

local ART = 2 -- the 12x12 Factorissimo building

for _, def in ipairs(defs.list) do
  local ports = layout.ports(def)
  local size = layout.size(def)
  local protos = def.kind == "silo" and blackbox.make_silo({
    name = def.name,
    parts = def.parts,
    recipe = def.recipe,
    map_color = def.map_color,
  }) or def.kind == "lab" and blackbox.make_lab({
    name = def.name,
    graphics = def.graphics,
    size = size,
    art = ART,
    inputs = def.inputs,
    researching_speed = def.researching_speed,
    power = def.power,
    map_color = def.map_color,
  }) or blackbox.make_city({
    name = def.name,
    graphics = def.graphics,
    size = size,
    art = ART,
    crafting_speed = def.crafting_speed,
    power = def.power,
    burner = def.burner and { fuel_categories = def.burner.fuel_categories, power = def.burner_power },
    recipe = def.recipe,
    fluid_boxes = fluid_boxes(def, ports, size),
    map_color = def.map_color,
  })
  -- Tooltip = description + click hint; the city window shows the description alone.
  for _, p in ipairs(protos) do
    if p.type == "assembling-machine" or p.type == "lab" or p.type == "rocket-silo" then
      p.localised_description = { "tt-gui.click-hint", { "tt-city-description." .. defs.entity_name(def.name) } }
    end
  end
  data:extend(protos)

  if def.generator_usage then
    -- The power city's hidden generator: same footprint, no collision, not selectable.
    data:extend({
      {
        type = "generator",
        name = defs.generator_name(def),
        icon = "__base__/graphics/icons/steam-engine.png",
        hidden = true,
        flags = { "placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable",
          "not-selectable-in-game", "not-rotatable", "not-in-kill-statistics", "not-upgradable", "no-copy-paste" },
        max_health = 10000,
        collision_box = { { -size / 2 + 0.1, -size / 2 + 0.1 }, { size / 2 - 0.1, size / 2 - 0.1 } },
        -- no selection box: hovering/clicking must reach the city underneath (playtest 1.10)
        selectable_in_game = false,
        collision_mask = { layers = {} },
        effectivity = 1,
        fluid_usage_per_tick = def.generator_usage,
        maximum_temperature = def.steam_temp or defs.POWER_STEAM_TEMP,
        fluid_box = {
          volume = 200 * def.generator_usage / 3,
          filter = "steam",
          production_type = "input",
          ---@diagnostic disable-next-line: missing-fields
          pipe_connections = { { connection_type = "linked", linked_connection_id = 1, flow_direction = "input" } },
        },
        energy_source = { type = "electric", usage_priority = "secondary-output" },
      },
    })
  end
end
