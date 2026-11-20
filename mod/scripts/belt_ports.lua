-- Belt ports (PLAN 2.10.4). Every item a city takes or gives has a port in its wall: a
-- hidden loader (prototypes/belt_port.lua) under the wall tile, filtered to that item. The
-- player's belt ends on the tile just outside and runs in (or out). Where each port sits
-- comes from shared/port_layout.lua; the markers drawn here show the item and which way
-- it goes. Fluid ports (pipe connections) get the same markers.
--
-- record.belt_ports = { LuaEntity, ... } (the loaders; markers are attached to them or
-- to the city, so they go when those go).
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local port_layout = require("shared.port_layout")
local cities = require("scripts.cities")

local M = {}

local INWARD = {
  [defines.direction.north] = defines.direction.south, [defines.direction.south] = defines.direction.north,
  [defines.direction.east] = defines.direction.west, [defines.direction.west] = defines.direction.east,
}

--- Arrow on the ground just outside the port, pointing the way items go, and the item's
--- icon on the wall above the port.
---@param city LuaEntity
---@param spot table port_layout.spot result
---@param sprite string
---@param inward boolean
local function draw_marker(city, spot, sprite, inward)
  local out_dir = spot.direction
  local dir = inward and INWARD[out_dir] or out_dir
  rendering.draw_sprite({
    sprite = "utility/indication_arrow",
    orientation = dir / 16,
    target = { entity = city, offset = spot.outside },
    surface = city.surface,
    x_scale = 0.7, y_scale = 0.7,
    render_layer = "lower-object-above-shadow",
  })
  rendering.draw_sprite({
    sprite = sprite,
    target = { entity = city, offset = spot.inside },
    surface = city.surface,
    x_scale = 0.6, y_scale = 0.6,
    render_layer = "higher-object-above",
  })
end

--- Build the ports for a city's tier: loaders for items, markers for items and fluids.
---@param city LuaEntity
---@param record table
function M.attach(city, record)
  local info = city_defs.by_entity[city.name]
  if not info then return end
  local size = port_layout.size(info.def, info.tier)
  record.belt_ports = {}
  for _, p in ipairs(port_layout.ports(info.def)) do
    if p.tiers[info.tier] and (p.kind == "item" or p.kind == "fluid") then
      local spot = port_layout.spot(p, size)
      local inward = p.flow == "input"
      if p.kind == "item" then
        local loader = city.surface.create_entity({
          name = config.BELT_PORT,
          position = { city.position.x + spot.inside[1], city.position.y + spot.inside[2] },
          direction = inward and INWARD[spot.direction] or spot.direction,
          type = inward and "input" or "output",
          force = city.force,
          create_build_effect_smoke = false,
        })
        if loader then
          loader.set_filter(1, p.name)
          loader.loader_filter_mode = "whitelist"
          cities.protect(loader)
          record.belt_ports[#record.belt_ports + 1] = loader
        end
      end
      draw_marker(city, spot, (p.kind == "item" and "item/" or "fluid/") .. p.name, inward)
    end
  end
end

--- Remove a city's ports (upgrade, destruction).
---@param record table
function M.detach(record)
  for _, loader in ipairs(record.belt_ports or {}) do
    if loader.valid then loader.destroy() end
  end
  record.belt_ports = nil
end

cities.on_any_placed(M.attach)

--- The loaders of a city (tests, UI).
---@param city LuaEntity
function M.of(city)
  local record = storage.tt_cities[city.unit_number]
  local out = {}
  for _, loader in ipairs(record and record.belt_ports or {}) do
    if loader.valid then out[#out + 1] = loader end
  end
  return out
end

return M
