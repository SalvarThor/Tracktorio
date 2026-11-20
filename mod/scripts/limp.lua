-- Limp mode for fuel-empty locomotives (SPEC MVP). See DECISIONS.md A3 / 1.7.
--
-- There is no fuel-empty event or train state, so tracked locomotives are polled in slices:
--   * nothing burning and an empty fuel inventory -> burn the hidden limp fuel (slow)
--   * limp fuel burning and real fuel in the inventory -> drop it; the burner takes the real
--     fuel on its next energy request
--
-- storage.tt_limp = { locos = { { entity, unit, seen }, ... }, index = { [unit] = i }, cursor = n }
local config = require("shared.config")
local reliability = require("scripts.reliability")

local M = {}

function M.init()
  storage.tt_limp = storage.tt_limp or { locos = {}, index = {}, cursor = 1 }
end

---@param loco LuaEntity
function M.track(loco)
  local s = storage.tt_limp
  if not (loco.valid and loco.type == "locomotive") or s.index[loco.unit_number] then return end
  s.locos[#s.locos + 1] = { entity = loco, unit = loco.unit_number }
  s.index[loco.unit_number] = #s.locos
end

--- Remove the record at position i by moving the last record into its place.
local function untrack_at(i)
  local s = storage.tt_limp
  local last = #s.locos
  s.index[s.locos[i].unit] = nil
  reliability.forget(s.locos[i].unit)
  if i ~= last then
    s.locos[i] = s.locos[last]
    s.index[s.locos[i].unit] = i
  end
  s.locos[last] = nil
end
--- Rebuild tracking from the map (init / configuration change).
function M.scan()
  M.init()
  local s = storage.tt_limp
  s.locos, s.index, s.cursor = {}, {}, 1
  for _, surface in pairs(game.surfaces) do
    for _, loco in pairs(surface.find_entities_filtered({ type = "locomotive" })) do M.track(loco) end
  end
end

---@param burner LuaBurner
local function burning_name(burner)
  local cur = burner.currently_burning
  if not cur then return nil end
  local name = cur.name
  return type(name) == "string" and name or name.name
end

--- Apply the limp rules to one locomotive. Returns "limp", "restored" or nil.
---@param loco LuaEntity
function M.check(loco)
  local burner = loco.burner
  if not burner then return nil end
  local inv = burner.inventory
  local burning = burning_name(burner)
  if reliability.train_broken(loco) then
    -- broken down (2.3.2): limp even with fuel inside, until the train is repaired
    if burning == config.LIMP_FUEL then return nil end
    burner.currently_burning = config.LIMP_FUEL
    burner.remaining_burning_fuel = config.LIMP_FUEL_JOULES
    return "limp"
  end
  if burning == nil and inv.is_empty() then
    burner.currently_burning = config.LIMP_FUEL
    burner.remaining_burning_fuel = config.LIMP_FUEL_JOULES
    return "limp"
  elseif burning == config.LIMP_FUEL and not inv.is_empty() then
    burner.currently_burning = nil
    return "restored"
  end
  return nil
end

---@param loco LuaEntity
function M.is_limping(loco)
  return loco.burner ~= nil and burning_name(loco.burner) == config.LIMP_FUEL
end

--- Check the next slice of locomotives (every LIMP_INTERVAL ticks).
function M.tick()
  local s = storage.tt_limp
  local n = #s.locos
  if n == 0 then return end
  local per_slice = math.ceil(n * config.LIMP_INTERVAL / config.LIMP_PASS_TICKS)
  local i = s.cursor
  local done = 0
  while done < per_slice and #s.locos > 0 do
    if i > #s.locos then i = 1 end
    local loco = s.locos[i].entity
    if loco.valid then
      M.check(loco)
      reliability.update(s.locos[i])
      i = i + 1
    else
      untrack_at(i) -- the swapped-in entry is checked next
    end
    done = done + 1
  end
  s.cursor = i
end

--- A locomotive was built (control.lua dispatches the build events).
---@param entity LuaEntity
function M.on_built(entity)
  if entity.type == "locomotive" then M.track(entity) end
end

function M.remote_interface()
  return {
    --- Check every tracked locomotive now (tests).
    check_all = function()
      for _, r in ipairs(storage.tt_limp.locos) do if r.entity.valid then M.check(r.entity) end end
    end,
    is_limping = function(loco) return M.is_limping(loco) end,
    tracked = function() return #storage.tt_limp.locos end,
  }
end

return M
