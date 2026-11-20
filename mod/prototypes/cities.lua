-- City prototypes: one per tier, from shared/city_defs.lua.
local blackbox = require("prototypes.blackbox")
local defs = require("shared.city_defs")
local layout = require("shared.port_layout")

--- Fluid boxes for a tier: piped fluids at their port spots (shared/port_layout.lua), then
--- hidden linked boxes as defined.
---@param def table
---@param ports table[]
---@param tier integer
---@param size integer
local function fluid_boxes(def, ports, tier, size)
  local boxes = {}
  for _, p in ipairs(ports) do
    if p.kind == "fluid" and p.tiers[tier] then
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

for _, def in ipairs(defs.list) do
  local ports = layout.ports(def)
  for tier, t in ipairs(def.tiers) do
    local size = layout.size(def, tier)
    local suffix = tier == 1 and def.name or (def.name .. "-t" .. tier)
    local protos = def.kind == "silo" and blackbox.make_silo({
      name = suffix,
      parts = def.parts,
      recipe = t.recipe,
      map_color = def.map_color,
    }) or def.kind == "lab" and blackbox.make_lab({
      name = suffix,
      graphics = def.graphics,
      size = size,
      art = tier,
      inputs = def.inputs,
      researching_speed = t.researching_speed,
      power = t.power,
      map_color = def.map_color,
    }) or blackbox.make_city({
      name = suffix,
      graphics = def.graphics,
      size = size,
      art = tier,
      crafting_speed = t.crafting_speed,
      power = t.power,
      burner = def.burner and { fuel_categories = def.burner.fuel_categories, power = t.burner_power },
      recipe = t.recipe,
      fluid_boxes = fluid_boxes(def, ports, tier, size),
      map_color = def.map_color,
    })
    -- Tooltip = description + click hint; the city window shows the description alone.
    for _, p in ipairs(protos) do
      if p.type == "assembling-machine" or p.type == "lab" or p.type == "rocket-silo" then
        p.localised_description = { "tt-gui.click-hint", { "tt-city-description." .. defs.entity_name(def.name, tier) } }
      end
    end
    if tier > 1 then
      -- recipe and category reuse the city's display name; the entity has its own locale
      local entity_name = defs.entity_name(def.name, tier)
      for _, p in ipairs(protos) do
        if p.type ~= "assembling-machine" then p.localised_name = { "entity-name." .. entity_name } end
      end
    end
    data:extend(protos)

    if t.generator_usage then
      -- The power city's hidden generator: same footprint, no collision, not selectable.
      data:extend({
        {
          type = "generator",
          name = defs.generator_name(tier, def),
          localised_name = { "entity-name." .. defs.generator_name(1, def) },
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
          fluid_usage_per_tick = t.generator_usage,
          maximum_temperature = def.steam_temp or defs.POWER_STEAM_TEMP,
          fluid_box = {
            volume = 200 * t.generator_usage / 3,
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
end
