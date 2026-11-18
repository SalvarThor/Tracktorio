-- City detail window, opened by clicking a city (custom input linked to "open-gui").
-- storage.tt_city_gui[player_index] = city unit_number while the window is open.
local cities = require("scripts.cities")
local city_info = require("scripts.city_info")

local M = {}

local FRAME = "tt_city_frame"
M.OPEN_INPUT = "tt-open-city"

function M.init()
  storage.tt_city_gui = storage.tt_city_gui or {}
end

local function sprite_for(kind, name)
  return (kind == "fluid" and "fluid/" or "item/") .. name
end

local function fmt(n)
  if n >= 100 then return string.format("%d", math.floor(n + 0.5)) end
  return string.format("%.1f", n)
end

---@param parent LuaGuiElement
local function add_line(parent, entry, text)
  local flow = parent.add({ type = "flow", direction = "horizontal" })
  flow.style.vertical_align = "center"
  flow.add({ type = "sprite", sprite = sprite_for(entry.type, entry.name) })
  flow.add({ type = "label", caption = text })
end

---@param frame LuaGuiElement
---@param info table
local function fill(frame, info)
  local body = frame.body
  body.clear()
  if not info.recipe then
    body.add({ type = "label", caption = { "tt-gui.city-no-recipe" } })
    return
  end

  -- status
  local status_caption
  if info.status == "running" then
    status_caption = { "tt-gui.city-status-running" }
  elseif info.status == "output_full" then
    status_caption = { "tt-gui.city-status-output-full" }
  elseif info.status == "starved" then
    local names = {}
    for _, n in ipairs(info.missing or {}) do
      names[#names + 1] = (prototypes.item[n] and "[item=" or "[fluid=") .. n .. "]"
    end
    ---@type any
    local missing = table.concat(names, " ")
    status_caption = { "tt-gui.city-status-starved", missing }
  else
    status_caption = { "tt-gui.city-status-other", info.status_detail or "?" }
  end
  local status = body.add({ type = "label", name = "status", caption = status_caption })
  status.style.font = "default-bold"

  -- recipe
  body.add({ type = "label", caption = { "tt-gui.city-inputs" }, style = "caption_label" })
  for _, ing in ipairs(info.recipe.ingredients) do
    add_line(body, ing, { "tt-gui.city-input-line", fmt(ing.amount), fmt(ing.per_min_max) })
  end
  body.add({ type = "label", caption = { "tt-gui.city-outputs" }, style = "caption_label" })
  for _, p in ipairs(info.recipe.products) do
    add_line(body, p, { "tt-gui.city-output-line", fmt(p.amount), fmt(p.per_min), fmt(p.per_min_max) })
  end
  ---@type any
  local cycle = { "tt-gui.city-cycle", fmt(info.recipe.energy) }
  body.add({ type = "label", caption = cycle })
end

---@param player LuaPlayer
---@param entity LuaEntity
function M.open(player, entity)
  M.close(player)
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })
  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.add({ type = "label", caption = entity.localised_name, style = "frame_title", ignored_by_interaction = true })
  local filler = titlebar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  filler.style.horizontally_stretchable = true
  filler.style.height = 24
  titlebar.add({ type = "sprite-button", name = "tt_city_close", sprite = "utility/close", style = "frame_action_button" })
  local body = frame.add({ type = "frame", name = "body", direction = "vertical", style = "inside_shallow_frame_with_padding" })
  body.style.minimal_width = 300
  frame.auto_center = true
  storage.tt_city_gui[player.index] = entity.unit_number
  fill(frame, city_info.info(entity))
  player.opened = frame
end

---@param player LuaPlayer
function M.close(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then frame.destroy() end
  storage.tt_city_gui[player.index] = nil
end

--- Refresh open windows (called every GOAL_TICK_INTERVAL).
function M.update_all()
  for index, unit in pairs(storage.tt_city_gui) do
    local player = game.get_player(index)
    local record = storage.tt_cities[unit]
    local frame = player and player.gui.screen[FRAME]
    if not (player and frame and frame.valid and record and record.entity.valid) then
      if player then M.close(player) else storage.tt_city_gui[index] = nil end
    else
      fill(frame, city_info.info(record.entity))
    end
  end
end

---@param e EventData.CustomInputEvent
local function on_open_input(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local selected = player.selected
  if cities.is_city(selected) and selected and selected.type == "assembling-machine" then
    M.open(player, selected)
  end
end

---@param e EventData.on_gui_click
local function on_gui_click(e)
  if e.element.valid and e.element.name == "tt_city_close" then
    local player = game.get_player(e.player_index)
    if player then M.close(player) end
  end
end

---@param e EventData.on_gui_closed
local function on_gui_closed(e)
  if e.element and e.element.valid and e.element.name == FRAME then
    local player = game.get_player(e.player_index)
    if player then M.close(player) end
  end
end

function M.register_events()
  script.on_event(M.OPEN_INPUT, on_open_input)
  script.on_event(defines.events.on_gui_click, on_gui_click)
  script.on_event(defines.events.on_gui_closed, on_gui_closed)
end

return M
