-- Rocket silo city (PLAN 2.5.6). The engine builds the rocket from parts; once one is ready
-- the script launches it (no space platforms, no launch button). Each launch is counted and
-- reported to hooks (the win condition, 2.5.7).
--
-- storage.tt_rockets_launched = number
local M = {}

local launched_hooks = {}
---@param fn fun(silo: LuaEntity?)
function M.on_launched(fn) launched_hooks[#launched_hooks + 1] = fn end

function M.init()
  storage.tt_rockets_launched = storage.tt_rockets_launched or 0
end

---@param entity LuaEntity?
function M.is_silo(entity)
  return entity ~= nil and entity.valid and entity.type == "rocket-silo" and storage.tt_cities[entity.unit_number] ~= nil
end

--- Launch every ready rocket of a silo city (every GOAL_TICK_INTERVAL).
function M.tick()
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid and e.type == "rocket-silo" and e.rocket_silo_status == defines.rocket_silo_status.rocket_ready then
      e.launch_rocket()
    end
  end
end

---@param e EventData.on_rocket_launched
local function on_rocket_launched(e)
  if not M.is_silo(e.rocket_silo) then return end
  M.init()
  storage.tt_rockets_launched = storage.tt_rockets_launched + 1
  for _, fn in ipairs(launched_hooks) do fn(e.rocket_silo) end
end

--- Silo progress for the window and tests.
---@param entity LuaEntity
function M.status(entity)
  local status = entity.rocket_silo_status
  local name = "other"
  for k, v in pairs(defines.rocket_silo_status) do if v == status then name = k end end
  return {
    parts = entity.rocket_parts,
    required = entity.prototype.rocket_parts_required,
    status = name,
    launched = storage.tt_rockets_launched or 0,
  }
end

function M.register_events()
  script.on_event(defines.events.on_rocket_launched, on_rocket_launched)
end

return M
