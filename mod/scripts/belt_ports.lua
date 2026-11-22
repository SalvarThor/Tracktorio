-- Belt ports (PLAN 2.10.4). Every item a city takes or gives has a port in its wall: a
-- hidden loader (prototypes/belt_port.lua) under the wall tile, filtered to that item.
-- The player's belt ends on the tile just outside and runs in (or out). Where each port sits
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

local CHECK_TICKS = 10

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

--- The icon painted on a city's roof: `roof_icon` from its definition, else its first
--- product. Nil for the rocket silo (it keeps the vanilla silo).
---@param def table
local function roof_sprite(def)
  if def.roof_icon then return def.roof_icon end
  if def.kind == "silo" then return nil end
  local recipe = def.recipe
  local p = recipe and recipe.results and recipe.results[1]
  return p and ((p.type == "fluid" and "fluid/" or "item/") .. p.name) or nil
end

--- A large icon of what the city makes, painted on its roof as in Factorissimo (2.10), so
--- cities tell apart at a glance. Scaled with the building; drawn on the city.
---@param city LuaEntity
---@param def table
---@param size integer
local function draw_roof(city, def, size)
  local sprite = roof_sprite(def)
  if not sprite then return end
  local k = size / 8
  rendering.draw_sprite({
    sprite = sprite,
    target = { entity = city, offset = { 0, -1.2 * k } }, -- the middle of the roof in the art
    surface = city.surface,
    x_scale = 1.8 * k, y_scale = 1.8 * k, -- a 64 px icon is 2 tiles at scale 1
    render_layer = "higher-object-under",
  })
end

--- Build a city's ports: loaders for items, markers for items and fluids.
---@param city LuaEntity
---@param record table
function M.attach(city, record)
  local info = city_defs.by_entity[city.name]
  if not info then return end
  local size = port_layout.size(info.def)
  draw_roof(city, info.def, size)
  record.belt_ports = {}
  for _, p in ipairs(port_layout.ports(info.def)) do
    local spot = port_layout.spot(p, size)
    local inward = p.flow == "input"
    if p.kind ~= "fluid" then
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
        if not inward then
          storage.tt_output_ports = storage.tt_output_ports or {}
          storage.tt_output_ports[loader.unit_number] = { loader = loader, diff = 0, seen = {},
            a = loader.get_transport_line(defines.transport_line.left_line),
            b = loader.get_transport_line(defines.transport_line.right_line) }
        end
      end
    end
    draw_marker(city, spot, (p.kind == "item" and "item/" or "fluid/") .. p.name, inward)
  end
end

--- Output ports fill both lanes evenly (2.10.19, user). The engine's loader puts single
--- items on one lane until it backs up, which a slow city (the depot's 2 fuel/s) shows:
--- one lane full, then the other. Each output port keeps a tally of the items it has put
--- on each lane; a new item on the busier lane moves to the other. Items are told apart by
--- their unique ids, so one seen on two checks counts once. Called every tick
--- (control.lua); each port is looked at every other tick.
--- storage.tt_output_ports[loader unit_number] = { loader = LuaEntity, a, b = its two
--- LuaTransportLines, diff = lane 1 minus lane 2, seen = { [id] = true } }, kept by
--- attach/detach.
function M.balance()
  local ports = storage.tt_output_ports
  if not ports then return end
  local parity = game.tick % 2
  for unit, t in pairs(ports) do
    local loader = t.loader
    if not loader.valid then
      ports[unit] = nil
    elseif unit % 2 == parity then -- each port every other tick (an item stays longer than that)
      local a, b = t.a, t.b
      if #a + #b == 0 then
        t.seen = {}
      elseif not (a.can_insert_at_back() or b.can_insert_at_back()) then
        -- backed up: nothing moves, nothing new arrives
      else
        local lines = { a, b }
        -- new items on both lanes first, then moves, then what is there now (a moved item
        -- must not count again on its new lane)
        local fresh = {}
        for lane = 1, 2 do
          for _, d in pairs(lines[lane].get_detailed_contents()) do
            -- copy name and quality now: moving an item invalidates the other items' stacks
            -- (playtest 2.12 crash)
            if not t.seen[d.unique_id] then
              fresh[#fresh + 1] = { lane = lane, name = d.stack.name, quality = d.stack.quality.name }
            end
          end
        end
        for _, f in ipairs(fresh) do
          local lane = f.lane
          local busier = (lane == 1 and t.diff > 0) or (lane == 2 and t.diff < 0)
          local other = lines[3 - lane]
          local stack = { name = f.name, count = 1, quality = f.quality }
          local landed = lane
          if busier and other.can_insert_at_back() and lines[lane].remove_item(stack) == 1 then
            if other.insert_at_back(stack) then landed = 3 - lane else lines[lane].insert_at_back(stack) end
          end
          t.diff = t.diff + (landed == 1 and 1 or -1)
        end
        local now = {}
        for lane = 1, 2 do
          for _, d in pairs(lines[lane].get_detailed_contents()) do now[d.unique_id] = true end
        end
        t.seen = now
      end
    end
  end
end

--- Remove a city's ports (destruction, the upgrade planner's swap).
---@param record table
function M.detach(record)
  for _, loader in ipairs(record.belt_ports or {}) do
    if loader.valid then
      if storage.tt_output_ports then storage.tt_output_ports[loader.unit_number] = nil end
      loader.destroy()
    end
  end
  record.belt_ports = nil
end

cities.on_any_placed(M.attach)

--- Is this inserter reaching into a city or one of its ports? (The MVP goal box, which only
--- old saves and tests have, still takes inserters.)
---@param inserter LuaEntity
local function reaches_city(inserter)
  local function is_city(t)
    return t ~= nil and t.valid and (t.name == config.BELT_PORT
      or (cities.is_city(t) and t.name ~= config.CITY.goal))
  end
  return is_city(inserter.pickup_target) or is_city(inserter.drop_target)
end

--- An inserter finds what it reaches a few ticks after it is built or turned, so the check
--- waits: storage.tt_inserter_checks = { { entity, player_index, tick }, ... }, each looked
--- at every tick for CHECK_TICKS (its first target is not always the final one).
---@param inserter LuaEntity
---@param player_index integer?
function M.check_inserter(inserter, player_index)
  if not (inserter.valid and inserter.type == "inserter") then return end
  storage.tt_inserter_checks = storage.tt_inserter_checks or {}
  table.insert(storage.tt_inserter_checks, { entity = inserter, player_index = player_index, tick = game.tick })
end

--- Run the checks queued before this tick (control.lua calls this every tick; cheap when
--- the queue is empty).
function M.tick()
  local queue = storage.tt_inserter_checks
  if not (queue and queue[1]) then return end
  local later = {}
  for _, c in ipairs(queue) do
    local e = c.entity
    if not e.valid then -- gone already
    elseif c.tick >= game.tick then later[#later + 1] = c
    elseif reaches_city(e) then M.refuse(e, c.player_index)
    elseif game.tick - c.tick < CHECK_TICKS then
      later[#later + 1] = c -- its targets may not be found yet: look again next tick
    end
  end
  storage.tt_inserter_checks = later
end

--- No inserters on cities (2.10.5): an inserter that reaches a city goes back to the
--- player who placed it, with a message saying to use the belt ports.
---@param inserter LuaEntity
---@param player_index integer?
function M.refuse(inserter, player_index)
  if not (inserter.valid and reaches_city(inserter)) then return end
  storage.tt_inserters_refused = (storage.tt_inserters_refused or 0) + 1
  local player = player_index and game.get_player(player_index)
  if player then
    player.create_local_flying_text({ text = { "tt-notify.no-inserters" }, position = inserter.position })
    if player.mine_entity(inserter, true) then return end
  end
  if inserter.valid then inserter.destroy() end
end

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
