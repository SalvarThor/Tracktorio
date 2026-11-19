-- Locomotive reliability (PLAN 2.3, DECISIONS 2026-11-19): reliability is the locomotive's
-- health. Driving wears it down at a per-prototype rate, never below RELIABILITY_FLOOR, and a
-- moving locomotive may break down, more likely the lower its health. A broken locomotive
-- makes its whole train limp (limp.lua) until it is back at full health, by servicing or by
-- hand with repair packs.
-- limp.lua's sliced poll calls M.update for each tracked locomotive (about once a second).
--
-- storage.tt_reliability = { broken = { [unit_number] = true } }
local config = require("shared.config")

local M = {}

-- Called with (loco) when a locomotive breaks down / is cured (notifications).
local breakdown_hooks, cured_hooks = {}, {}
---@param fn fun(loco: LuaEntity)
function M.on_breakdown(fn) breakdown_hooks[#breakdown_hooks + 1] = fn end
---@param fn fun(loco: LuaEntity)
function M.on_cured(fn) cured_hooks[#cured_hooks + 1] = fn end

function M.init()
  storage.tt_reliability = storage.tt_reliability or { broken = {} }
end

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

--- Chance that a locomotive at `fraction` health breaks down within `ticks` of driving.
---@param fraction number
---@param ticks number
function M.chance(fraction, ticks)
  local per_second = config.BREAKDOWN_CHANCE * (1 - fraction) ^ 2
  return 1 - (1 - per_second) ^ (ticks / 60)
end

---@param loco LuaEntity
function M.is_broken(loco)
  local s = storage.tt_reliability
  return s ~= nil and loco.unit_number ~= nil and s.broken[loco.unit_number] == true
end

--- Is any locomotive of this locomotive's train broken?
---@param loco LuaEntity
function M.train_broken(loco)
  local train = loco.train
  if not train then return M.is_broken(loco) end
  for _, group in pairs(train.locomotives) do
    for _, l in pairs(group) do
      if l.valid and M.is_broken(l) then return true end
    end
  end
  return false
end

---@param loco LuaEntity
function M.break_down(loco)
  if M.is_broken(loco) or not loco.unit_number then return end
  storage.tt_reliability.broken[loco.unit_number] = true
  for _, fn in ipairs(breakdown_hooks) do fn(loco) end
end

---@param loco LuaEntity
local function cure(loco)
  storage.tt_reliability.broken[loco.unit_number] = nil
  for _, fn in ipairs(cured_hooks) do fn(loco) end
end

--- A tracked locomotive is gone.
---@param unit integer
function M.forget(unit)
  if storage.tt_reliability then storage.tt_reliability.broken[unit] = nil end
end

--- Poll step for one tracked locomotive record ({ entity, unit, seen }).
---@param record table
function M.update(record)
  local loco = record.entity ---@type LuaEntity
  local now = game.tick
  local since = record.seen and (now - record.seen) or 0
  record.seen = now
  if M.is_broken(loco) then
    if loco.health >= loco.max_health then cure(loco) end
    return
  end
  local train = loco.train
  if train and train.speed ~= 0 and since > 0 then
    M.wear(loco, since)
    if math.random() < M.chance(M.fraction(loco), since) then M.break_down(loco) end
  end
end

return M
