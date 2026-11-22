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
    mod_version = script.active_mods["tracktorio"],
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

--- /tt-goal            print goal progress
--- /tt-goal <iron> <copper>   set the targets (playtest tuning; remote twin: tt-goal.set_targets)
---@param cmd CustomCommandData
local function cmd_goal(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  local args = {}
  for word in string.gmatch(cmd.parameter or "", "%S+") do args[#args + 1] = tonumber(word) end
  if #args >= 1 then
    if player and not player.admin then player.print("tt-goal: admins only"); return end
    remote.call("tt-goal", "set_targets", args[1], args[2] or args[1])
  end
  local s = remote.call("tt-goal", "status")
  local msg = string.format("tt-goal: iron %d/%d, copper %d/%d, won=%s",
    s.delivered.iron, s.targets.iron, s.delivered.copper, s.targets.copper, tostring(s.won))
  if player then player.print(msg) else log(msg) end
end

--- /tt-silo-fill <parts>   set the rocket parts of the rocket silo city under the cursor
--- (playtest helper; admins only; remote twin: tt-city.silo_fill(entity, parts))
---@param cmd CustomCommandData
local function cmd_silo_fill(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  if not player then return end
  if not player.admin then player.print("tt-silo-fill: admins only"); return end
  local parts = tonumber(cmd.parameter or "")
  local target = player.selected
  if not (parts and target and target.type == "rocket-silo") then
    player.print("tt-silo-fill: hover over the rocket silo and type /tt-silo-fill <parts>")
    return
  end
  local ok, err = pcall(remote.call, "tt-city", "silo_fill", target, parts)
  player.print(ok and ("tt-silo-fill: " .. parts .. " parts") or ("tt-silo-fill: " .. tostring(err)))
end

function M.register()
  commands.add_command("tt-silo-fill", "Set the rocket parts of the rocket silo under the cursor: /tt-silo-fill <parts> (playtest helper).", cmd_silo_fill)
  commands.add_command("tt-dump", "Write a JSON snapshot of Tracktorio's storage to script-output/tt-dump.json.", cmd_dump)
  commands.add_command("tt-goal", "Show goal progress. /tt-goal <iron> <copper> sets the targets.", cmd_goal)
  remote.add_interface("tt-debug", {
    dump = function() return M.dump() end,
  })
end

return M
