-- Debug commands (/tt-*) and the matching remote interface "tt-debug".
-- Tests and playtests rely on these; keep them working.

local M = {}

M.DUMP_FILE = "tt-dump.json"

--- Copy of a value that JSON can hold: Lua objects become small descriptive tables.
local function sanitize(v, seen)
  local t = type(v)
  if t == "userdata" then
    local ok, desc = pcall(function()
      if not v.valid then return { object = v.object_name, valid = false } end
      local d = { object = v.object_name, valid = true }
      if v.object_name == "LuaEntity" then
        d.name, d.unit_number, d.position = v.name, v.unit_number, v.position
      end
      return d
    end)
    return ok and desc or tostring(v)
  elseif t == "table" then
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local out = {}
    for k, val in pairs(v) do out[tostring(k)] = sanitize(val, seen) end
    seen[v] = nil
    return out
  elseif t == "function" then
    return "<function>"
  end
  return v
end

--- Write a JSON snapshot of storage to script-output/tt-dump.json and return the JSON.
---@param player_index uint? write only on this player's machine (nil = everywhere/server)
---@return string
function M.dump(player_index)
  local json = helpers.table_to_json({
    tick = game.tick,
    mod_version = script.active_mods["train-tycoon"],
    storage = sanitize(storage, {}),
  })
  helpers.write_file(M.DUMP_FILE, json, false, player_index)
  return json
end

---@param cmd CustomCommandData
local function cmd_dump(cmd)
  M.dump(cmd.player_index)
  local msg = "tt-dump: wrote script-output/" .. M.DUMP_FILE
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if player then player.print(msg) else log(msg) end
end

function M.register()
  commands.add_command("tt-dump", "Write a JSON snapshot of Train Tycoon's storage to script-output/tt-dump.json.", cmd_dump)
  remote.add_interface("tt-debug", {
    dump = function() return M.dump() end,
  })
end

return M
