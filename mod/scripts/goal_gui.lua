-- Goal progress panel (top-left), updated with the goal tick.
local goal = require("scripts.goal")

local M = {}

local FRAME = "tt_goal_frame"

---@param player LuaPlayer
local function build(player)
  local root = player.gui.left
  if root[FRAME] then root[FRAME].destroy() end
  local frame = root.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "tt-gui.goal-title" } })
  for _, key in ipairs({ "iron", "copper" }) do
    local flow = frame.add({ type = "flow", name = key, direction = "vertical" })
    flow.add({ type = "label", name = "label" })
    local bar = flow.add({ type = "progressbar", name = "bar", value = 0 })
    bar.style.horizontally_stretchable = true
    bar.style.minimal_width = 220
  end
end

---@param player LuaPlayer
function M.update(player)
  local frame = player.gui.left[FRAME]
  if not (frame and frame.valid) then build(player); frame = player.gui.left[FRAME] end
  local s = goal.status()
  for _, key in ipairs({ "iron", "copper" }) do
    local flow = frame[key]
    local done, target = s.delivered[key], s.targets[key]
    flow.label.caption = { "tt-gui.goal-line-" .. key, done, target, math.floor(s.rates[key] + 0.5) }
    flow.bar.value = math.min(1, done / target)
  end
end

function M.update_all()
  for _, player in pairs(game.connected_players) do M.update(player) end
end

---@param e EventData.on_player_created
function M.on_player_created(e)
  local player = game.get_player(e.player_index)
  if player then build(player); M.update(player) end
end

function M.rebuild_all()
  for _, player in pairs(game.players) do build(player) end
end

return M
