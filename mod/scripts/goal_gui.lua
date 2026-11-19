-- Goal progress panel (top-left), updated with the goal tick. Since 2.5.7 the goal is a
-- rocket launch: the panel shows the rocket silo city's parts, or that the game is won.
local goal = require("scripts.goal")
local silo = require("scripts.silo")

local M = {}

local FRAME = "tt_goal_frame"

---@param player LuaPlayer
local function build(player)
  local root = player.gui.left
  if root[FRAME] then root[FRAME].destroy() end
  local frame = root.add({ type = "frame", name = FRAME, direction = "vertical", caption = { "tt-gui.goal-rocket-title" } })
  local flow = frame.add({ type = "flow", name = "rocket", direction = "vertical" })
  flow.add({ type = "label", name = "label" })
  local bar = flow.add({ type = "progressbar", name = "bar", value = 0 })
  bar.style.horizontally_stretchable = true
  bar.style.minimal_width = 220
end

--- The silo city closest to launching, or nil.
local function best_silo()
  local best, best_parts = nil, -1
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid and e.type == "rocket-silo" and e.rocket_parts > best_parts then best, best_parts = e, e.rocket_parts end
  end
  return best
end

---@param player LuaPlayer
function M.update(player)
  local frame = player.gui.left[FRAME]
  if not (frame and frame.valid and frame["rocket"]) then build(player); frame = player.gui.left[FRAME] end
  local flow = frame["rocket"]
  if goal.status().won then
    flow.label.caption = { "tt-gui.goal-rocket-won" }
    flow.bar.value = 1
    return
  end
  local s = best_silo()
  if not s then
    flow.label.caption = { "tt-gui.goal-rocket-no-silo" }
    flow.bar.value = 0
    return
  end
  local st = silo.status(s)
  flow.label.caption = { "tt-gui.goal-rocket-parts", tostring(st.parts), tostring(st.required) }
  flow.bar.value = st.required > 0 and math.min(1, st.parts / st.required) or 0
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
