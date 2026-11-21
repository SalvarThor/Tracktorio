-- City detail window, opened by clicking a city (custom input linked to "open-gui").
-- storage.tt_city_gui[player_index] = the LuaEntity (city or port) shown while the window is open.
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")
local city_info = require("scripts.city_info")
local goal = require("scripts.goal")
local service = require("scripts.service")

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

-- Status colours (2.13): green running, red starved, orange output full, yellow power.
local GREEN, RED, ORANGE, YELLOW = { 0.55, 0.9, 0.45 }, { 1, 0.45, 0.4 }, { 1, 0.7, 0.3 }, { 1, 0.88, 0.35 }
local HINT = { 0.75, 0.75, 0.75 }

--- A section heading after a separator, with its explanation as a tooltip.
---@param body LuaGuiElement
---@param caption LocalisedString
---@param tooltip LocalisedString?
local function add_heading(body, caption, tooltip)
  body.add({ type = "line", direction = "horizontal" })
  return body.add({ type = "label", caption = caption, style = "caption_label", tooltip = tooltip })
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

--- Where on the wall a port is, as a locale key ("top left", "left side, top"...).
---@param p table city_info.ports entry
local function port_where(p)
  local along = math.abs(p.offset) < 0.01 and "mid" or (p.offset < 0 and "a" or "b")
  return { "tt-gui.city-pipe-pos-" .. p.side .. "-" .. along }
end

--- Short "what to do" for a starved city: where its first missing input goes in.
---@param info table
local function starved_hint(info)
  local name = info.missing and info.missing[1]
  if not name then return nil end
  for _, p in ipairs(info.ports or {}) do
    if p.flow == "input" and p.name == name then
      local fluid = prototypes.fluid[name] ~= nil
      return { fluid and "tt-gui.city-hint-starved-pipe" or "tt-gui.city-hint-starved-belt", icon_list({ name }), port_where(p) }
    end
  end
  return nil
end

--- Status line, coloured, and a short hint only when something is wrong.
---@param body LuaGuiElement
---@param entity LuaEntity
---@param info table
local function add_status(body, entity, info)
  local status, hint, color, tip
  if info.status == "running" and info.speed and info.speed < 100 then
    -- 2.12: fed below its full rate, it runs steadily at that rate
    status, color, tip = { "tt-gui.city-status-running-at", tostring(info.speed) }, GREEN, { "tt-gui.city-hint-running-at" }
  elseif info.status == "running" then
    status, color = { "tt-gui.city-status-running" }, GREEN
  elseif info.status == "low_power" then
    status, hint, color = { "tt-gui.city-status-low-power" }, { "tt-gui.city-hint-low-power" }, YELLOW
  elseif info.status == "no_power" then
    status, hint, color = { "tt-gui.city-status-no-power" }, { "tt-gui.city-hint-no-power" }, YELLOW
  elseif info.status == "output_full" and city_defs.is_power(entity.name) then
    status, color, tip = { "tt-gui.city-status-power-idle" }, YELLOW, { "tt-gui.city-hint-power-idle" }
  elseif info.status == "output_full" then
    local names, fluid = {}, false
    for _, n in ipairs(info.full or {}) do
      local is_fluid = prototypes.fluid[n] ~= nil
      fluid = fluid or is_fluid
      names[#names + 1] = (is_fluid and "[fluid=" or "[item=") .. n .. "]"
    end
    status = #names > 0 and { "tt-gui.city-status-output-full-named", table.concat(names, " ") } or { "tt-gui.city-status-output-full" }
    hint, color = fluid and { "tt-gui.city-hint-output-full-fluid" } or { "tt-gui.city-hint-output-full" }, ORANGE
  elseif info.status == "starved" then
    status, hint, color = { "tt-gui.city-status-starved", icon_list(info.missing) }, starved_hint(info), RED
  else
    status, color = { "tt-gui.city-status-other", info.status_detail or "?" }, YELLOW
  end
  local label = add_text(body, status, true, "status")
  label.style.font_color = color
  if tip then label.tooltip = tip end
  if hint then add_text(body, hint, false, "hint").style.font_color = HINT end
  if info.power_use and info.status == "running" then
    add_text(body, { "tt-gui.city-power-use", tostring(math.floor(info.power_use * 100 + 0.5)) }, false, "power_use")
  end
  if info.also_missing and #info.also_missing > 0 then
    add_text(body, { "tt-gui.city-also-missing", icon_list(info.also_missing) }, false, "also_missing")
  end
end

--- Flows as a table: item, in/out, now per minute, max per minute, held in the city.
---@param body LuaGuiElement
---@param entity LuaEntity
---@param info table
local function add_flows(body, entity, info)
  body.add({ type = "line", direction = "horizontal" })
  local t = body.add({ type = "table", name = "flows", column_count = 5 })
  t.style.horizontal_spacing = 14
  for i = 3, 5 do
    ---@diagnostic disable-next-line: assign-type-mismatch
    t.style.column_alignments[i] = "right"
  end
  for _, key in ipairs({ "", "", "tt-gui.flows-now", "tt-gui.flows-max", "tt-gui.flows-held" }) do
    t.add({ type = "label", caption = key ~= "" and { key } or "", style = "caption_label" })
  end
  -- crafts per minute now, from the first product's measured rate
  local first = info.recipe.products[1]
  local crafts_now = first and first.amount > 0 and (first.per_min or 0) / first.amount or 0
  local out_inv = entity.get_inventory(defines.inventory.crafter_output)
  local function row(entry, flow, now, max, held)
    local proto = entry.type == "fluid" and prototypes.fluid[entry.name] or prototypes.item[entry.name]
    t.add({ type = "sprite", sprite = sprite_for(entry.type, entry.name), tooltip = proto and proto.localised_name or nil })
    t.add({ type = "label", caption = { flow } })
    t.add({ type = "label", caption = now and fmt(now) or "-" })
    t.add({ type = "label", caption = fmt(max) })
    t.add({ type = "label", caption = fmt(held) })
  end
  for _, ing in ipairs(info.recipe.ingredients) do
    if ing.fuel then
      row(ing, "tt-gui.flows-fuel", nil, ing.per_min_max, ing.have or 0)
    else
      row(ing, "tt-gui.city-pipe-in", crafts_now * ing.amount, ing.per_min_max, ing.have or 0)
    end
  end
  for _, p in ipairs(info.recipe.products) do
    local held = p.type == "fluid" and entity.get_fluid_count(p.name) or (out_inv and out_inv.get_item_count(p.name) or 0)
    row(p, "tt-gui.city-pipe-out", p.per_min or 0, p.per_min_max, held)
  end
end

local BELT_ITEM = { yellow = "transport-belt", red = "fast-transport-belt", blue = "express-transport-belt", turbo = "turbo-transport-belt" }

--- Every port: item, in/out, where on the wall and the belt it needs at full output (an
--- icon; the rate in the tooltip). Signals as one line, explained in its tooltip.
---@param body LuaGuiElement
---@param port_list table[]?
local function add_ports(body, port_list)
  if not port_list or #port_list == 0 then return end
  add_heading(body, { "tt-gui.city-ports" }, { "tt-gui.city-ports-tip" })
  for i, p in ipairs(port_list) do
    local what = p.kind == "service" and "[item=repair-pack]"
      or ("[" .. p.kind .. "=" .. p.name .. "]")
    ---@type any
    local extra = ""
    ---@type any
    local tip = nil
    if p.kind == "service" then tip = { "tt-gui.city-port-service-tip" }
    elseif p.belt then
      local belt = "[item=" .. BELT_ITEM[p.belt] .. "]"
      extra, tip = belt, { "tt-gui.city-port-belt-tip", belt, fmt(p.per_s) }
    elseif p.per_s then extra = { "tt-gui.city-port-rate", fmt(p.per_s) } end
    local label = add_text(body, { "tt-gui.city-port-line", what,
      { p.flow == "input" and "tt-gui.city-pipe-in" or "tt-gui.city-pipe-out" }, port_where(p), extra }, false, "port-" .. i)
    if tip then label.tooltip = tip end
  end
  -- 2.11: the signal point in the door
  add_text(body, { "tt-gui.city-signals", "[img=item/constant-combinator]" }, false, "signals").tooltip =
    { "tt-gui.city-signals-tip" }
end

--- A depot's servicing in one line; the rules in its tooltip (2.3.3).
---@param body LuaGuiElement
---@param city LuaEntity
local function add_service(body, city)
  local s = service.status(city)
  if not s then return end
  local how = { "tt-gui.service-how", tostring(config.SERVICE_RANGE) }
  add_heading(body, { "tt-gui.service-title" }, how)
  add_text(body, { "tt-gui.service-packs", "[item=" .. config.SERVICE_ITEM .. "]", tostring(s.packs or 0), tostring(s.serviced) },
    false, "service").tooltip = how
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
    add_text(body, { "tt-gui.lab-status-no-research" }, true, "status").style.font_color = YELLOW
    add_text(body, { "tt-gui.lab-hint-no-research" }, false, "hint").style.font_color = HINT
  elseif info.unsupported and #info.unsupported > 0 then
    add_text(body, { "tt-gui.lab-status-unsupported", icons(info.unsupported) }, true, "status").style.font_color = RED
  elseif info.status == "missing_packs" then
    add_text(body, { "tt-gui.lab-status-missing", icons(info.missing) }, true, "status").style.font_color = RED
  else
    add_status(body, entity, info)
  end
  if info.research then
    add_text(body, { "tt-gui.lab-research", "[technology=" .. info.research .. "]",
      prototypes.technology[info.research].localised_name }, false, "research")
  end
  body.add({ type = "line", direction = "horizontal" })
  local packs = body.add({ type = "flow", direction = "horizontal", name = "packs" })
  packs.style.vertical_align = "center"
  packs.add({ type = "label", caption = { "tt-gui.lab-packs" }, style = "caption_label" })
  for _, p in ipairs(info.lab.packs) do
    packs.add({ type = "sprite", sprite = "item/" .. p.name, tooltip = prototypes.item[p.name].localised_name })
    packs.add({ type = "label", caption = tostring(p.count) })
  end
  add_text(body, { "tt-gui.lab-speed", tostring(math.floor(info.lab.speed + 0.5)) })
  add_ports(body, info.ports)
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
  add_flows(body, entity, info)
  if info.silo then
    body.add({ type = "line", direction = "horizontal" })
    local parts = add_text(body, { "tt-gui.silo-parts", tostring(info.silo.parts), tostring(info.silo.required) }, true, "silo")
    ---@type any
    local how = { "tt-gui.silo-how", tostring(info.silo.required) }
    parts.tooltip = how
    local bar = body.add({ type = "progressbar", value = info.silo.required > 0 and info.silo.parts / info.silo.required or 0 })
    bar.style.horizontally_stretchable = true
    add_text(body, { "tt-gui.silo-launched", tostring(info.silo.launched) })
  end
  add_ports(body, info.ports)
  add_service(body, entity)
end

--- The city a belt port belongs to.
---@param port LuaEntity
local function city_of_belt_port(port)
  for _, record in pairs(storage.tt_cities) do
    for _, loader in ipairs(record.belt_ports or {}) do
      if loader == port and record.entity.valid then return record.entity end
    end
    for _, point in pairs(record.signal_points or {}) do -- 2.11
      if point == port and record.entity.valid then return record.entity end
    end
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
  if entity.name == config.CITY.goal then
    fill_goal(body)
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

--- Entities with a window: crafting cities, the goal box, service ports.
---@param entity LuaEntity?
function M.has_window(entity)
  if not (entity and entity.valid) then return false end
  if entity.name == config.SERVICE_PORT then return true end
  return cities.is_city(entity) and (entity.type == "assembling-machine" or entity.type == "lab" or entity.type == "rocket-silo"
    or entity.name == config.CITY.goal)
end
---@param player LuaPlayer
---@param entity LuaEntity
function M.open(player, entity)
  M.close(player)
  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })
  local titlebar = frame.add({ type = "flow", name = "titlebar", direction = "horizontal" })
  titlebar.drag_target = frame
  -- 2.13: the description is the title's tooltip (cities: without the "click it" hint)
  local description = city_defs.by_entity[entity.name] and { "tt-city-description." .. entity.name } or entity.localised_description
  titlebar.add({ type = "label", name = "title", caption = entity.localised_name, style = "frame_title", tooltip = description })
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
  -- with a wire in hand, a click on a signal point connects the wire: no window
  local cursor = player.cursor_stack
  if selected and selected.name == config.SIGNAL_POINT and cursor and cursor.valid_for_read then
    return
  end
  -- a belt port (2.10) or signal point (2.11) opens its city's window
  if selected and (selected.name == config.BELT_PORT or selected.name == config.SERVICE_BOX_PORT
      or selected.name == config.SIGNAL_POINT) then
    selected = city_of_belt_port(selected)
  end
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
