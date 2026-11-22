-- Black box cities at runtime: placement (by script, or built by the player since 2.15),
-- protection, hands-off enforcement, tracking, removal.
-- Cities are entities named "tt-city-*" (see prototypes/blackbox.lua).
--
-- storage.tt_cities[unit_number] = { entity = LuaEntity, name = string, surface_index,
--   position, companion = LuaEntity?, belt_ports, signal_points, throttle (their modules),
--   radar }
-- storage.tt_hand_transfers = count of hand transfers that reached a city (should stay 0;
--   operable=false is expected to block them, see DECISIONS.md A2).

local config = require("shared.config")

local M = {}

M.PREFIX = "tt-city-"

-- name -> function(entity) run after a city of that name is placed (registered at load time).
local placed_hooks = {}

---@param name string
---@param fn fun(entity: LuaEntity)
function M.on_placed(name, fn)
  placed_hooks[name] = fn
end

-- functions(entity, record) run after any city is placed (registered at load time).
local any_placed_hooks = {}

---@param fn fun(entity: LuaEntity, record: table)
function M.on_any_placed(fn)
  any_placed_hooks[#any_placed_hooks + 1] = fn
end

-- functions(old_record, new_record) run when a city replaces another in place (the upgrade
-- planner's swap, 2.15.4), before the old one's parts are removed: the old record's entity
-- is already gone, its parts are still there (signals.lua keeps the player's wires).
local replace_hooks = {}

---@param fn fun(old: table, new: table)
function M.on_replace(fn)
  replace_hooks[#replace_hooks + 1] = fn
end

-- functions(record) run after a city is gone (mined, destroyed), its parts removed. Not
-- for a city replaced in place: the new one's placed hooks cover that.
local removed_hooks = {}

---@param fn fun(record: table)
function M.on_removed(fn)
  removed_hooks[#removed_hooks + 1] = fn
end

---@param name string?
function M.is_city_name(name)
  return name ~= nil and string.sub(name, 1, #M.PREFIX) == M.PREFIX
end

---@param entity LuaEntity?
function M.is_city(entity)
  return entity ~= nil and entity.valid and M.is_city_name(entity.name)
end

function M.init()
  storage.tt_cities = storage.tt_cities or {}
  storage.tt_hand_transfers = storage.tt_hand_transfers or 0
end

--- Hands-off protection for a city: nobody opens, damages or rotates it. It stays minable:
--- the player may remove a city they built (its contents are lost, see on_pre_mined).
---@param entity LuaEntity
function M.protect_city(entity)
  entity.operable = false
  entity.destructible = false
  entity.rotatable = false
end

--- Hands-off protection for a city's attached entities (ports, points, generator, ...).
---@param entity LuaEntity
function M.protect(entity)
  entity.operable = false
  entity.destructible = false
  entity.minable_flag = false
  entity.rotatable = false
end

--- Where a city asked for at `position` (a tile centre) really stands. Even sizes (12x12)
--- centre on a tile corner: the corner at the top left of the tile asked for, so callers
--- can keep passing tile centres.
---@param name string city entity name
---@param position MapPosition|number[]
---@return MapPosition
function M.snap(name, position)
  local x = position.x or position[1]
  local y = position.y or position[2]
  if prototypes.entity[name].tile_width % 2 == 0 then return { x = math.floor(x), y = math.floor(y) } end
  return { x = x, y = y }
end

--- Place a city by script.
---@param name string entity name, "tt-city-..."
---@param surface LuaSurface
---@param position MapPosition
---@param force ForceID?
---@return LuaEntity
function M.place(name, surface, position, force)
  assert(M.is_city_name(name), "tt: not a city: " .. tostring(name))
  assert(prototypes.entity[name], "tt: unknown city prototype: " .. name)
  M.init() -- the scenario may place cities before this mod's on_init has run
  position = M.snap(name, position)
  local entity = surface.create_entity({
    name = name,
    position = position,
    force = force or "player",
    create_build_effect_smoke = false,
  })
  assert(entity, "tt: could not place " .. name .. " at " .. serpent.line(position))
  M.adopt(entity)
  return entity
end

--- Remove a city's attached entities (ports, points, generator, beacon, radar).
---@param record table
local function remove_parts(record)
  if record.companion and record.companion.valid then record.companion.destroy() end
  for _, loader in ipairs(record.belt_ports or {}) do -- 2.10.4
    if loader.valid then loader.destroy() end
  end
  for _, point in pairs(record.signal_points or {}) do -- 2.11
    if point.valid then point.destroy() end
  end
  if record.throttle and record.throttle.beacon.valid then record.throttle.beacon.destroy() end -- 2.12
  if record.radar and record.radar.valid then record.radar.destroy() end -- 2.15.10
end

--- Track a city that now stands on the map, placed by script or built by the player (by
--- hand, ghost, robot, blueprint or the upgrade planner): protect it, give it its hidden
--- generator, and run the placement hooks (ports, signal point, throttle, radar). Records
--- whose city is gone are cleared first; one that stood at the same spot was just replaced
--- in place (2.15.4), so the replace hooks see it before its parts go.
---@param entity LuaEntity
---@return table record
function M.adopt(entity)
  M.init()
  local name = entity.name
  if storage.tt_cities[entity.unit_number] then return storage.tt_cities[entity.unit_number] end
  M.protect_city(entity)
  local record = { entity = entity, name = name, surface_index = entity.surface.index,
    position = { x = entity.position.x, y = entity.position.y } }
  for un, old in pairs(storage.tt_cities) do
    if not old.entity.valid then
      if old.surface_index == record.surface_index and old.position
          and old.position.x == record.position.x and old.position.y == record.position.y then
        for _, fn in ipairs(replace_hooks) do fn(old, record) end
      end
      remove_parts(old)
      storage.tt_cities[un] = nil
    end
  end
  local surface = entity.surface
  local comp = config.CITY_COMPANIONS[name]
  if comp then
    local companion = surface.create_entity({ name = comp.entity, position = entity.position, force = entity.force })
    assert(companion, "tt: could not place companion " .. comp.entity)
    M.protect(companion)
    entity.add_fluid_box_linked_connection(comp.city_link_id, companion, comp.companion_link_id)
    record.companion = companion
  end
  -- 2.15.10 (user, playtest): the city's surroundings stay live on the map
  local radar = surface.create_entity({ name = config.CITY_RADAR, position = entity.position, force = entity.force })
  assert(radar, "tt: could not place the city radar")
  M.protect(radar)
  record.radar = radar
  storage.tt_cities[entity.unit_number] = record
  script.register_on_object_destroyed(entity)
  if placed_hooks[name] then placed_hooks[name](entity) end
  for _, fn in ipairs(any_placed_hooks) do fn(entity, record) end
  return record
end

--- All valid tracked cities, optionally filtered by name.
---@param name string?
---@return LuaEntity[]
function M.list(name)
  local out = {}
  for _, c in pairs(storage.tt_cities) do
    if c.entity.valid and (not name or c.name == name) then out[#out + 1] = c.entity end
  end
  return out
end

---@param e EventData.on_object_destroyed
local function on_object_destroyed(e)
  if e.type == defines.target_type.entity and e.useful_id then
    local record = storage.tt_cities[e.useful_id]
    storage.tt_cities[e.useful_id] = nil
    if record then
      remove_parts(record)
      for _, fn in ipairs(removed_hooks) do fn(record) end
    end
  end
end

-- Belt and braces for hands-off: operable=false should already block both of these.
---@param e EventData.on_gui_opened
local function on_gui_opened(e)
  if e.gui_type == defines.gui_type.entity and M.is_city(e.entity) then
    local player = game.get_player(e.player_index)
    if player then player.opened = nil end
  end
end

---@param e EventData.on_player_fast_transferred
local function on_player_fast_transferred(e)
  if M.is_city(e.entity) then
    storage.tt_hand_transfers = storage.tt_hand_transfers + 1
    log("tt: hand transfer reached a city (from_player=" .. tostring(e.from_player) .. ")")
  end
end

--- A city the player (or a robot) is about to mine loses everything inside (decision 5,
--- 2.15): it is hands-off, so nothing may reach the player's inventory that way.
---@param e EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined
local function on_pre_mined(e)
  local entity = e.entity
  if not (M.is_city(entity) and storage.tt_cities[entity.unit_number]) then return end
  for i = 1, entity.get_max_inventory_index() do
    local inv = entity.get_inventory(i --[[@as defines.inventory]])
    if inv then inv.clear() end
  end
  entity.clear_fluid_inside()
  if entity.type == "rocket-silo" then entity.rocket_parts = 0 end
end

-- Event filter for the entity types cities are (build and mine events).
local CITY_TYPES = { { filter = "type", type = "assembling-machine" }, { filter = "type", type = "lab" },
  { filter = "type", type = "rocket-silo" } }
M.BUILD_FILTER = CITY_TYPES

--- A city was built by the player, a robot or a script that raised the event. control.lua
--- owns the build events (one handler each) and calls this.
---@param entity LuaEntity
function M.on_built(entity)
  if M.is_city(entity) then M.adopt(entity) end
end

function M.register_events()
  script.on_event(defines.events.on_pre_player_mined_item, on_pre_mined, CITY_TYPES)
  script.on_event(defines.events.on_robot_pre_mined, on_pre_mined, CITY_TYPES)
  script.on_event(defines.events.on_object_destroyed, on_object_destroyed)
  script.on_event(defines.events.on_gui_opened, on_gui_opened)
  script.on_event(defines.events.on_player_fast_transferred, on_player_fast_transferred)
end

function M.remote_interface()
  return {
    --- Place a city. Returns the entity.
    place = function(name, surface_index, position, force)
      return M.place(name, game.get_surface(surface_index) or game.surfaces[1], position, force)
    end,
    --- Unit numbers of tracked cities (optionally of one prototype).
    list = function(name)
      local out = {}
      for _, e in ipairs(M.list(name)) do out[#out + 1] = e.unit_number end
      return out
    end,
    hand_transfers = function() return storage.tt_hand_transfers end,
  }
end

return M
