-- Persistent state in `storage` and its migrations.
-- Storage keys use the prefix `tt_` (Lua identifiers can't contain '-').
--
-- Schema history:
--   1  MVP (Phase 1)
--   2  tier upgrades (Phase 2.1): construction ports, upgrade progress, window state holds
--      the shown entity instead of a unit number

local M = {}

M.SCHEMA = 2

function M.init()
  storage.tt_schema = M.SCHEMA
end

--- Run on every configuration change. Each step must be idempotent; the module-level
--- init()s have already created any missing tables. `steps` supplies the code that lives in
--- other modules: { ensure_ports = fn, legacy_windows = fn, ensure_tier_marks = fn }.
---@param steps table
function M.migrate(steps)
  local from = storage.tt_schema or 0
  if from < 2 then
    -- 1 -> 2: windows stored a unit number; close them (the window is rebuilt on next click).
    steps.legacy_windows()
  end
  -- Every version: every upgradable city has its port (also covers a blocked tile later).
  steps.ensure_ports()
  -- Every version: tier pips on every tiered city (added in mod 0.1.1, no schema change).
  steps.ensure_tier_marks()
  storage.tt_schema = M.SCHEMA
end

return M
