-- Tier pips (PLAN 2.1.7): one marker per tier in the middle of a city's top edge (2.10.13:
-- small, and clear of the port markers at +-2.5), filled up to the city's tier. Drawn with LuaRendering attached to the city, so they vanish with it; an
-- upgraded city is a new entity and gets fresh pips from the on_any_placed hook.
--
-- record.tier_marks = { <render object id>, ... }
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")

local M = {}

M.RADIUS = 0.2 -- playtest 2.10: smaller (was 0.34)
M.SPACING = 0.55
M.FILLED = { r = 1, g = 0.78, b = 0.2, a = 1 }
M.EMPTY = { r = 0.15, g = 0.15, b = 0.15, a = 0.8 }
M.OUTLINE = { r = 0, g = 0, b = 0, a = 1 }

---@param record table
local function has_marks(record)
  local ids = record.tier_marks
  if not ids or #ids == 0 then return false end
  for _, id in ipairs(ids) do
    local obj = rendering.get_object_by_id(id)
    if not (obj and obj.valid) then return false end
  end
  return true
end

---@param record table
local function clear(record)
  for _, id in ipairs(record.tier_marks or {}) do
    local obj = rendering.get_object_by_id(id)
    if obj and obj.valid then obj.destroy() end
  end
  record.tier_marks = nil
end

--- Draw the pips for a city (replacing any it has). Cities without tiers, or with only one
--- (the rocket silo), get none.
---@param city LuaEntity
---@param record table
function M.draw(city, record)
  clear(record)
  local info = city_defs.by_entity[record.name]
  if not (info and info.max_tier > 1) then return end
  local box, pos = city.bounding_box, city.position
  local x0 = -(info.max_tier - 1) * M.SPACING / 2 -- centred on the top edge, between the ports
  local y0 = box.left_top.y - pos.y + 0.6
  local ids = {}
  for i = 1, info.max_tier do
    local target = { entity = city, offset = { x0 + (i - 1) * M.SPACING, y0 } }
    local filled = i <= info.tier
    ids[#ids + 1] = rendering.draw_circle({
      color = filled and M.FILLED or M.EMPTY, radius = M.RADIUS, filled = true,
      target = target, surface = city.surface }).id
    ids[#ids + 1] = rendering.draw_circle({
      color = M.OUTLINE, radius = M.RADIUS, width = 2, filled = false,
      target = target, surface = city.surface }).id
  end
  record.tier_marks = ids
end

cities.on_any_placed(M.draw)

--- Every tiered city has its pips, and single-tier cities have none (migration of older
--- saves, where the rocket silo got one pip; idempotent).
function M.ensure_all()
  for _, record in pairs(storage.tt_cities) do
    if record.entity.valid then
      local info = city_defs.by_entity[record.name]
      if not (info and info.max_tier > 1) then
        clear(record)
      elseif not has_marks(record) then
        M.draw(record.entity, record)
      end
    end
  end
end

--- Pips of a city for tests: { filled = n, total = n } or nil.
---@param city LuaEntity
function M.status(city)
  local record = storage.tt_cities[city.unit_number]
  if not (record and has_marks(record)) then return nil end
  local filled, total = 0, 0
  for _, id in ipairs(record.tier_marks) do
    local obj = rendering.get_object_by_id(id)
    if obj and obj.filled then
      total = total + 1
      if obj.color.r > 0.9 then filled = filled + 1 end
    end
  end
  return { filled = filled, total = total }
end

return M
