-- Depot servicing (PLAN 2.3.3). Every depot city gets a fixed service port on the tile east
-- of its top-right corner; it takes repair packs only. Once a second, every locomotive of a
-- train stopped at a train stop within SERVICE_RANGE tiles of a depot's edge is repaired,
-- using packs from that depot's port. Back at full health, a broken-down locomotive is cured
-- (reliability.lua).
--
-- record.service_port = LuaEntity; record.service = { hp_credit = HP left from the last pack
--   opened, serviced = locomotives brought back to full health }
-- The port is not destroyed on upgrade: the new tier adopts it (and its packs).
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")

local M = {}

---@param name string city entity name
function M.has_service(name)
  local info = city_defs.by_entity[name]
  return info ~= nil and info.def.service == true
end

--- Tile centre of the service port: east of the city's top-right tile.
---@param city LuaEntity
function M.port_position(city)
  local box = city.bounding_box
  return { x = math.ceil(box.right_bottom.x) + 0.5, y = math.floor(box.left_top.y) + 0.5 }
end

---@param port LuaEntity
local function set_filters(port)
  local inv = assert(port.get_inventory(defines.inventory.chest))
  for i = 1, #inv do
    local f = inv.get_filter(i)
    if not f or f.name ~= config.SERVICE_ITEM then inv.set_filter(i, { name = config.SERVICE_ITEM }) end
  end
end

--- Give a depot its service port (adopting one already on the tile, e.g. after an upgrade).
--- Returns true when it has one; false if the tile is taken by something else.
---@param city LuaEntity
---@param record table
function M.attach(city, record)
  if not M.has_service(record.name) then return false end
  record.service = record.service or { hp_credit = 0, serviced = 0 }
  if record.service_port and record.service_port.valid then return true end
  local pos = M.port_position(city)
  local port = city.surface.find_entity(config.SERVICE_PORT, pos)
  if not port then
    if not city.surface.can_place_entity({ name = config.SERVICE_PORT, position = pos, force = city.force }) then return false end
    port = city.surface.create_entity({ name = config.SERVICE_PORT, position = pos, force = city.force, create_build_effect_smoke = false })
    if not port then return false end
    cities.protect(port)
  end
  record.service_port = port
  record.service_blocked_notified = nil
  set_filters(port)
  return true
end

cities.on_any_placed(M.attach)

-- Called once per depot whose service port tile is taken (message to the player).
local on_blocked = nil
---@param fn fun(record: table, position: MapPosition)
function M.on_blocked(fn) on_blocked = fn end

--- Give every depot its service port (migration; retried every second). Never removes what
--- the player built: a taken tile is reported once and retried.
function M.ensure_all()
  for _, record in pairs(storage.tt_cities) do
    local city = record.entity
    if city.valid and not (record.service_port and record.service_port.valid) and M.has_service(record.name) then
      if not M.attach(city, record) and not record.service_blocked_notified then
        record.service_blocked_notified = true
        if on_blocked then on_blocked(record, M.port_position(city)) end
      end
    end
  end
end

--- Repair `want` HP using the depot's packs. Returns the HP actually available.
---@param record table
---@param inv LuaInventory
---@param want number
local function draw_hp(record, inv, want)
  local s = record.service
  while s.hp_credit < want do
    if inv.remove({ name = config.SERVICE_ITEM, count = 1 }) == 0 then break end
    s.hp_credit = s.hp_credit + config.SERVICE_HP_PER_PACK
  end
  local got = math.min(want, s.hp_credit)
  s.hp_credit = s.hp_credit - got
  return got
end

--- Locomotives of trains stopped at train stops in range of a depot.
---@param city LuaEntity
local function stopped_locomotives(city)
  local box, r = city.bounding_box, config.SERVICE_RANGE
  local area = { { box.left_top.x - r, box.left_top.y - r }, { box.right_bottom.x + r, box.right_bottom.y + r } }
  local out, seen = {}, {}
  ---@param train LuaTrain?
  local function add(train)
    if not train or seen[train.id] then return end
    seen[train.id] = true
    for _, group in pairs(train.locomotives) do
      for _, loco in pairs(group) do out[#out + 1] = loco end
    end
  end
  for _, stop in pairs(city.surface.find_entities_filtered({ type = "train-stop", area = area })) do
    add(stop.get_stopped_train())
    -- manually driven trains are never "stopped at" a stop: any standing train close by counts
    for _, loco in pairs(city.surface.find_entities_filtered({ type = "locomotive", position = stop.position, radius = config.SERVICE_STOP_RADIUS })) do
      local train = loco.train
      if train and train.speed == 0 then add(train) end
    end
  end
  return out
end

--- Service every stopped train near a depot (every GOAL_TICK_INTERVAL ticks).
---@param seconds number? time since the last call (default: one GOAL_TICK_INTERVAL)
function M.tick(seconds)
  M.ensure_all()
  local done = {} -- a locomotive near two depots is serviced once
  local per_loco = config.SERVICE_HP_PER_SECOND * (seconds or config.GOAL_TICK_INTERVAL / 60)
  for _, record in pairs(storage.tt_cities) do
    local port = record.service_port
    if record.entity.valid and port and port.valid then
      local inv = assert(port.get_inventory(defines.inventory.chest))
      for _, loco in ipairs(stopped_locomotives(record.entity)) do
        local missing = loco.max_health - loco.health
        if missing > 0 and not done[loco.unit_number] then
          done[loco.unit_number] = true
          local hp = draw_hp(record, inv, math.min(per_loco, missing))
          if hp > 0 then
            loco.health = math.min(loco.max_health, loco.health + hp)
            if loco.health >= loco.max_health then record.service.serviced = record.service.serviced + 1 end
          end
        end
      end
    end
  end
end

--- Service status of a depot, for the UI and tests.
---@param city LuaEntity
function M.status(city)
  local record = storage.tt_cities[city.unit_number]
  if not (record and record.service) then return nil end
  local port = record.service_port
  if not (port and port.valid) then port = nil end
  local packs = port and port.get_inventory(defines.inventory.chest).get_item_count(config.SERVICE_ITEM) or 0
  return { port = port, packs = packs, serviced = record.service.serviced, hp_credit = record.service.hp_credit }
end

--- The depot a service port belongs to.
---@param port LuaEntity
function M.city_of_port(port)
  for _, record in pairs(storage.tt_cities) do
    if record.service_port == port and record.entity.valid then return record.entity end
  end
  return nil
end

return M
