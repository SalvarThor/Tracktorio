-- Locomotive reliability (PLAN 2.3, DECISIONS 2026-11-19): reliability is the locomotive's
-- health. Driving wears it down at a per-prototype rate, never below RELIABILITY_FLOOR.
-- limp.lua's sliced poll calls M.update for each tracked locomotive (about once a second).
local config = require("shared.config")

local M = {}

---@param loco LuaEntity
function M.fraction(loco)
  local max = loco.max_health
  return (max and max > 0) and (loco.health / max) or 1
end

---@param loco LuaEntity
---@param fraction number 0..1 of max health
function M.set(loco, fraction)
  local max = loco.max_health
  loco.health = math.max(1, math.min(1, fraction) * max)
end

--- Apply `ticks` of driving wear to a locomotive.
---@param loco LuaEntity
---@param ticks number
function M.wear(loco, ticks)
  local rate = config.RELIABILITY_DECAY_PER_MINUTE[loco.name]
  if not rate or ticks <= 0 then return end
  local now = M.fraction(loco)
  if now <= config.RELIABILITY_FLOOR then return end
  M.set(loco, math.max(config.RELIABILITY_FLOOR, now - rate * ticks / 3600))
end

--- Poll step for one tracked locomotive record ({ entity, unit, seen }).
---@param record table
function M.update(record)
  local loco = record.entity ---@type LuaEntity
  local now = game.tick
  local since = record.seen and (now - record.seen) or 0
  record.seen = now
  local train = loco.train
  if train and train.speed ~= 0 then M.wear(loco, since) end
end

return M
