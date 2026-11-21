-- Persistent state in `storage` and its migrations.
-- Storage keys use the prefix `tt_` (Lua identifiers can't contain '-').
--
-- Schema history:
--   1  MVP (Phase 1)
--   2  tier upgrades (Phase 2.1); the window state holds the shown entity
--   3  player-built cities, no tiers (Phase 2.15)

local M = {}

M.SCHEMA = 3

function M.init()
  storage.tt_schema = M.SCHEMA
end

--- Run on every configuration change. Pre-release (CLAUDE.md): no save migrations, only the
--- schema number.
function M.migrate()
  storage.tt_schema = M.SCHEMA
end

return M
