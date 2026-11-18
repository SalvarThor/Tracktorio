-- Persistent state in `storage` and its migrations.
-- Storage keys use the prefix `tt_` (Lua identifiers can't contain '-').

local M = {}

M.SCHEMA = 1

function M.init()
  storage.tt_schema = M.SCHEMA
end

function M.migrate()
  storage.tt_schema = storage.tt_schema or 0
  -- if storage.tt_schema < 2 then ... storage.tt_schema = 2 end
  storage.tt_schema = M.SCHEMA
end

return M
