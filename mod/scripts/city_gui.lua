-- City detail window, opened by clicking a city (custom input linked to "open-gui").
-- storage.tt_city_gui[player_index] = the LuaEntity (city or port) shown while the window is open.
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")
local city_info = require("scripts.city_info")
local goal = require("scripts.goal")
local ports = require("scripts.ports")
local notify = require("scripts.notify")
local service = require("scripts.service")

local M = {}

local FRAME = "tt_city_frame"
M.OPEN_INPUT = "tt-open-city"

function M.init()
  storage.tt_city_gui = storage.tt_city_gui or {}
end

--- Schema 1 stored a unit number per open window: close those windows.
function M.migrate_legacy()
  for index, shown in pairs(storage.tt_city_gui) do
    if type(shown) == "number" then
      local player = game.get_player(index)
      if player then M.close(player) else storage.tt_city_gui[index] = nil end
    end
  end
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

---@param body LuaGuiElement
---@param caption any
---@param bold boolean?
---@param name string?
local function add_text(body, caption, bold, name)
  local label = body.add({ type = "label", name = name, caption = caption })
  label.style.single_line = false
  label.style.maximal_width = 360
  if bold then label.style.font = "default-bold" end
  return label
end

---@param body LuaGuiElement
---@param entity LuaEntity
local function add_description(body, entity)
  -- Cities: their description without the tooltip's "click it" hint (playtest 2.2.8).
  local text = city_defs.by_entity[entity.name] and { "tt-city-description." .. entity.name } or entity.localised_description
  local desc = add_text(body, text)
  desc.style.font_color = { 0.8, 0.8, 0.8 }
  body.add({ type = "line", direction = "horizontal" })
end

--- Rich-text icons for item or fluid names.
---@param names string[]?
local function icon_list(names)
  local out = {}
  for _, n in ipairs(names or {}) do
    out[#out + 1] = (prototypes.item[n] and "[item=" or "[fluid=") .. n .. "]"
  end
  return table.concat(out, " ")
end

--- Status line (+ optional hint line) for a crafting city.
---@param body LuaGuiElement
---@param entity LuaEntity
---@param info table
local function add_status(body, entity, info)
  local status, hint
  if info.status == "running" then
    status = { "tt-gui.city-status-running" }
  elseif info.status == "low_power" then
    status, hint = { "tt-gui.city-status-low-power" }, { "tt-gui.city-hint-low-power" }
  elseif info.status == "no_power" then
    status, hint = { "tt-gui.city-status-no-power" }, { "tt-gui.city-hint-no-power" }
  elseif info.status == "output_full" and city_defs.is_power(entity.name) then
    status, hint = { "tt-gui.city-status-power-idle" }, { "tt-gui.city-hint-power-idle" }
  elseif info.status == "output_full" then
    local names, fluid = {}, false
    for _, n in ipairs(info.full or {}) do
      local is_fluid = prototypes.fluid[n] ~= nil
      fluid = fluid or is_fluid
      names[#names + 1] = (is_fluid and "[fluid=" or "[item=") .. n .. "]"
    end
    status = #names > 0 and { "tt-gui.city-status-output-full-named", table.concat(names, " ") } or { "tt-gui.city-status-output-full" }
    hint = fluid and { "tt-gui.city-hint-output-full-fluid" } or { "tt-gui.city-hint-output-full" }
  elseif info.status == "starved" then
    status = { "tt-gui.city-status-starved", icon_list(info.missing) }
  else
    status = { "tt-gui.city-status-other", info.status_detail or "?" }
  end
  add_text(body, status, true, "status")
  if hint then add_text(body, hint, false, "hint") end
  if info.also_missing and #info.also_missing > 0 then
    add_text(body, { "tt-gui.city-also-missing", icon_list(info.also_missing) }, false, "also_missing")
  end
end

--- Tier, next tier and the construction materials with progress bars.
---@param body LuaGuiElement
---@param city LuaEntity
local function add_tiers(body, city)
  local s = ports.status(city)
  if not s or s.max_tier <= 1 then return end
  body.add({ type = "line", direction = "horizontal" })
  add_text(body, { "tt-gui.tier-line", tostring(s.tier), tostring(s.max_tier), notify.describe(city.name) }, true, "tier")
  if not s.next then
    add_text(body, { "tt-gui.tier-top" })
    return
  end
  local next_tier = s.tier + 1
  add_text(body, { "tt-gui.tier-next", tostring(next_tier), notify.describe(s.next, city.name) })
  local items = {}
  for item in pairs(s.cost) do items[#items + 1] = item end
  table.sort(items)
  for _, item in ipairs(items) do
    local got, need = math.min(s.delivered[item] or 0, s.cost[item]), s.cost[item]
    add_line(body, { type = "item", name = item }, { "tt-gui.tier-material", tostring(got), tostring(need) })
    local bar = body.add({ type = "progressbar", value = got / need })
    bar.style.horizontally_stretchable = true
  end
  add_text(body, { "tt-gui.tier-where" })
end

--- Where each fluid connects (2.4.2).
---@param body LuaGuiElement
---@param connections table[]?
local function add_pipes(body, connections)
  if not connections or #connections == 0 then return end
  body.add({ type = "label", caption = { "tt-gui.city-pipes" }, style = "caption_label" })
  for i, c in ipairs(connections) do
    -- "bottom left", "top right", "left side, middle"... (playtest 2.4.6: no tile counts)
    local along = math.abs(c.offset) < 0.01 and "mid" or (c.offset < 0 and "a" or "b")
    add_text(body, { "tt-gui.city-pipe-line", "[fluid=" .. c.fluid .. "]",
      { c.kind == "input" and "tt-gui.city-pipe-in" or "tt-gui.city-pipe-out" },
      { "tt-gui.city-pipe-pos-" .. c.side .. "-" .. along } }, false, "pipe-" .. i)
  end
end

--- A depot's servicing: packs in the service port and locomotives serviced (2.3.3).
---@param body LuaGuiElement
---@param city LuaEntity
local function add_service(body, city)
  local s = service.status(city)
  if not s then return end
  body.add({ type = "line", direction = "horizontal" })
  add_text(body, { "tt-gui.service-title" }, true)
  add_text(body, s.port and { "tt-gui.service-packs", "[item=" .. config.SERVICE_ITEM .. "]", tostring(s.packs) }
    or { "tt-gui.service-no-port" }, false, "service")
  add_text(body, { "tt-gui.service-count", tostring(s.serviced) })
  add_text(body, { "tt-gui.service-how", tostring(config.SERVICE_RANGE) })
end

--- The research complex: status, current research and the packs inside.
---@param body LuaGuiElement
---@param entity LuaEntity
---@param info table
local function fill_lab(body, entity, info)
  local function icons(list)
    local out = {}
    for _, n in ipairs(list or {}) do out[#out + 1] = "[item=" .. n .. "]" end
    return table.concat(out, " ")
  end
  if info.status == "no_research" then
    add_text(body, { "tt-gui.lab-status-no-research" }, true, "status")
    add_text(body, { "tt-gui.lab-hint-no-research" }, false, "hint")
  elseif info.unsupported and #info.unsupported > 0 then
    add_text(body, { "tt-gui.lab-status-unsupported", icons(info.unsupported) }, true, "status")
  elseif info.status == "missing_packs" then
    add_text(body, { "tt-gui.lab-status-missing", icons(info.missing) }, true, "status")
  else
    add_status(body, entity, info)
  end
  if info.research then
    add_text(body, { "tt-gui.lab-research", "[technology=" .. info.research .. "]",
      prototypes.technology[info.research].localised_name }, false, "research")
  end
  body.add({ type = "label", caption = { "tt-gui.lab-packs" }, style = "caption_label" })
  for _, p in ipairs(info.lab.packs) do
    add_line(body, p, { "tt-gui.lab-pack-line", tostring(p.count) })
  end
  add_text(body, { "tt-gui.lab-speed", tostring(math.floor(info.lab.speed + 0.5)) })
  add_tiers(body, entity)
end

---@param body LuaGuiElement
---@param entity LuaEntity
local function fill_city(body, entity)
  local info = city_info.info(entity)
  if info.lab then return fill_lab(body, entity, info) end
  if not info.recipe then
    add_text(body, { "tt-gui.city-no-recipe" })
    return
  end
  add_status(body, entity, info)
  body.add({ type = "label", caption = { "tt-gui.city-inputs" }, style = "caption_label" })
  for _, ing in ipairs(info.recipe.ingredients) do
    add_line(body, ing, { "tt-gui.city-input-line", fmt(ing.amount), fmt(ing.per_min_max), fmt(ing.have or 0) })
  end
  body.add({ type = "label", caption = { "tt-gui.city-outputs" }, style = "caption_label" })
  for _, p in ipairs(info.recipe.products) do
    add_line(body, p, { "tt-gui.city-output-line", fmt(p.amount), fmt(p.per_min), fmt(p.per_min_max) })
  end
  add_text(body, { "tt-gui.city-cycle", fmt(info.recipe.energy) })
  if info.silo then
    body.add({ type = "line", direction = "horizontal" })
    add_text(body, { "tt-gui.silo-parts", tostring(info.silo.parts), tostring(info.silo.required) }, true, "silo")
    local bar = body.add({ type = "progressbar", value = info.silo.required > 0 and info.silo.parts / info.silo.required or 0 })
    bar.style.horizontally_stretchable = true
    add_text(body, { "tt-gui.silo-how", tostring(info.silo.required) })
    add_text(body, { "tt-gui.silo-launched", tostring(info.silo.launched) })
  end
  add_pipes(body, info.connections)
  add_service(body, entity)
  add_tiers(body, entity)
end

--- The city a construction port belongs to.
---@param port LuaEntity
local function city_of_port(port)
  for _, record in pairs(storage.tt_cities) do
    if record.port == port and record.entity.valid then return record.entity end
  end
  return nil
end

---@param body LuaGuiElement
local function fill_goal(body)
  local s = goal.status()
  add_text(body, s.won and { "tt-gui.goal-status-won" } or { "tt-gui.goal-status-open" }, true, "status")
  for _, key in ipairs({ "iron", "copper" }) do
    local item = config.GOAL_ITEMS[key]
    local done, target = s.delivered[key], s.targets[key]
    add_line(body, { type = "item", name = item }, { "tt-gui.goal-window-line",
      tostring(done), tostring(target), fmt(s.rates[key]),
      done < target and { "tt-gui.goal-accepting" } or { "tt-gui.goal-closed" } })
  end
end

---@param frame LuaGuiElement
---@param entity LuaEntity
local function fill(frame, entity)
  local body = frame.body
  body.clear()
  add_description(body, entity)
  if entity.name == config.CITY.goal then
    fill_goal(body)
  elseif entity.name == config.PORT then
    local city = city_of_port(entity)
    if city then
      add_text(body, { "tt-gui.port-for", city.localised_name }, true, "status")
      add_tiers(body, city)
    end
  elseif entity.name == config.SERVICE_PORT then
    local city = service.city_of_port(entity)
    if city then
      add_text(body, { "tt-gui.port-for", city.localised_name }, true, "status")
      add_service(body, city)
    end
  else
    fill_city(body, entity)
  end
end

--- Entities with a window: crafting cities, the goal box, construction and service ports.
---@param entity LuaEntity?
function M.has_window(entity)
  if not (entity and entity.valid) then return false end
  if entity.name == config.PORT or entity.name == config.SERVICE_PORT then return true end
  return cities.is_city(entity) and (entity.type == "assembling-machine" or entity.type == "lab" or entity.type == "rocket-silo"
    or entity.name == config.CITY.goal)
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
  storage.tt_city_gui[player.index] = entity
  fill(frame, entity)
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
  for index, entity in pairs(storage.tt_city_gui) do
    local player = game.get_player(index)
    local frame = player and player.gui.screen[FRAME]
    if not (player and frame and frame.valid and type(entity) ~= "number" and entity.valid) then
      if player then M.close(player) else storage.tt_city_gui[index] = nil end
    else
      fill(frame, entity)
    end
  end
end

---@param e EventData.CustomInputEvent
local function on_open_input(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  local selected = player.selected
  if selected and M.has_window(selected) then
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
