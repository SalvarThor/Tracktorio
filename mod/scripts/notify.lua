-- Player-facing upgrade messages (PLAN 2.1.4): chat message with a map link, custom alert,
-- flying text, a 90% heads-up, and a warning when the city's network looks too weak.
local city_defs = require("shared.city_defs")

local M = {}

local ALERT_TICKS = 60 * 30

function M.init()
  storage.tt_alerts = storage.tt_alerts or {} -- { { player_index, entity, expires? }, ... } (no expiry: removed by code)
end

local function mw(watts) return string.format("%.1f", watts / 1e6) end

---@param entity LuaEntity
local function gps(entity)
  return string.format("[gps=%d,%d,%s]", math.floor(entity.position.x), math.floor(entity.position.y), entity.surface.name)
end

--- Steam per tick -> watts (165 C steam: 30 kJ/unit).
local function generator_watts(usage) return usage * 60 * 30000 end

--- What a city tier does: { per_min, product, draw (W)?, output (W)?, coal = bool }.
---@param entity_name string
function M.tier_facts(entity_name)
  local proto = prototypes.entity[entity_name]
  local info = city_defs.by_entity[entity_name]
  local recipe = proto and proto.fixed_recipe
  local facts = { coal = false }
  if proto and info and proto.type == "lab" then
    facts.labs = proto.get_researching_speed()
    facts.draw = proto.get_max_energy_usage() * 60
    return facts
  end
  if not (proto and recipe and info) then return facts end
  local p = recipe.products[1]
  facts.product = p.name
  facts.product_type = p.type
  facts.per_min = (p.amount or 0) * 60 * proto.get_crafting_speed() / recipe.energy
  -- "uses coal": only for cities that burn an ingredient as fuel (def.fuel); the depot and
  -- power city consume coal as their main input at every tier
  for _, ing in ipairs(recipe.ingredients) do
    if info.def.fuel and ing.name == info.def.fuel then facts.coal = true end
  end
  if proto.electric_energy_source_prototype then facts.draw = proto.get_max_energy_usage() * 60 end
  local t = info.def.tiers[info.tier]
  if t.generator_usage then facts.output = generator_watts(t.generator_usage) end
  return facts
end

--- Localised description of a tier: "makes up to 1800 [item]/min, draws up to 8.6 MW, ..."
---@param entity_name string
---@param previous string? entity name of the previous tier (to mention "no longer uses coal")
function M.describe(entity_name, previous)
  local f = M.tier_facts(entity_name)
  ---@type any[]
  local parts = { "" }
  if f.labs then
    parts[#parts + 1] = { "tt-notify.labs", tostring(math.floor(f.labs + 0.5)) }
  elseif f.output then
    parts[#parts + 1] = { "tt-notify.power-out", mw(f.output) }
  elseif f.per_min then
    local icon = (f.product_type == "fluid" and "[fluid=" or "[item=") .. f.product .. "]"
    parts[#parts + 1] = { "tt-notify.rate", tostring(math.floor(f.per_min + 0.5)), icon }
  end
  if f.draw then parts[#parts + 1] = { "tt-notify.power-draw", mw(f.draw) } end
  if previous and M.tier_facts(previous).coal and not f.coal then parts[#parts + 1] = { "tt-notify.no-coal" } end
  return parts
end

--- Base (tier-independent) name of a city, e.g. "Iron smelting city".
---@param entity_name string
function M.base_name(entity_name)
  local info = city_defs.by_entity[entity_name]
  return info and { "entity-name." .. city_defs.entity_name(info.def.name, 1) } or { "entity-name." .. entity_name }
end

--- Power check for an electric city: nil if fine, else a localised warning.
--- Compares the max draw of all tracked cities on the same network with the output of the
--- power cities on it (other consumers like drills come on top).
---@param city LuaEntity
function M.network_warning(city)
  local facts = M.tier_facts(city.name)
  if not facts.draw then return nil end
  if not city.is_connected_to_electric_network() then return { "tt-notify.not-connected" } end
  local net = city.electric_network_id
  local demand, supply = 0, 0
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid then
      local f = M.tier_facts(e.name)
      if f.draw and e.electric_network_id == net then demand = demand + f.draw end
      if f.output and record.companion and record.companion.valid and record.companion.electric_network_id == net then
        supply = supply + f.output
      end
    end
  end
  if demand > supply then return { "tt-notify.weak-network", mw(demand), mw(supply) } end
  return nil
end

---@param force LuaForce
---@param message LocalisedString
local function tell(force, message)
  force.print(message, { sound_path = "utility/new_objective" })
  -- last messages, for tests and /tt-dump
  local log_ = storage.tt_notify_log or {}
  storage.tt_notify_log = log_
  log_[#log_ + 1] = { tick = game.tick, message = message }
  while #log_ > 20 do table.remove(log_, 1) end
end

--- Recent messages (newest last).
function M.recent() return storage.tt_notify_log or {} end

--- After an upgrade: chat, alert, flying text.
---@param old_name string
---@param city LuaEntity
function M.upgraded(old_name, city)
  local info = city_defs.by_entity[city.name]
  local tier = info and info.tier or 0
  ---@type any
  local message = { "tt-notify.upgraded", gps(city), M.base_name(city.name), tostring(tier), M.describe(city.name, old_name) }
  local warning = M.network_warning(city)
  if warning then message = { "", message, " ", warning } end
  tell(city.force --[[@as LuaForce]], message)
  for _, player in pairs(city.force.connected_players) do
    ---@type any
    local alert_text = { "tt-notify.alert", M.base_name(city.name), tostring(tier) }
    player.add_custom_alert(city, { type = "entity", name = city.name }, alert_text, true)
    storage.tt_alerts[#storage.tt_alerts + 1] = { player_index = player.index, entity = city, expires = game.tick + ALERT_TICKS }
    if player.surface == city.surface then
      ---@type any
      local flying = { "tt-notify.flying", tostring(tier) }
      player.create_local_flying_text({ text = flying, position = city.position, time_to_live = 180 })
    end
  end
end

--- 90% heads-up, once per tier.
---@param record table
function M.heads_up(record)
  local city = record.entity
  local target = record.upgrade and record.upgrade.target
  if not (city and city.valid and target) then return end
  local info = city_defs.by_entity[target]
  ---@type any
  local message = { "tt-notify.heads-up", gps(city), M.base_name(city.name), tostring(info and info.tier or 0), M.describe(target, city.name) }
  tell(city.force --[[@as LuaForce]], message)
end

--- A city's construction port tile is taken; tell the player once.
---@param record table
---@param position MapPosition
function M.port_blocked(record, position)
  local city = record.entity
  if not (city and city.valid) then return end
  ---@type any
  local message = { "tt-notify.port-blocked", string.format("[gps=%d,%d,%s]", math.floor(position.x), math.floor(position.y), city.surface.name),
    M.base_name(city.name) }
  tell(city.force --[[@as LuaForce]], message)
end

--- A new city's spot on an extended map is taken by something the player built (2.2.6).
---@param label string
---@param surface LuaSurface
---@param position MapPosition
function M.city_blocked(label, surface, position)
  ---@type any
  local message = { "tt-notify.city-blocked", label,
    string.format("[gps=%d,%d,%s]", math.floor(position.x), math.floor(position.y), surface.name) }
  tell(game.forces["player"], message)
end

--- A locomotive broke down (2.3.2): chat message and an alert that stays until it is repaired.
---@param loco LuaEntity
function M.breakdown(loco)
  ---@type any
  local message = { "tt-notify.breakdown", gps(loco) }
  tell(loco.force --[[@as LuaForce]], message)
  for _, player in pairs(loco.force.connected_players) do
    player.add_custom_alert(loco, { type = "entity", name = loco.name }, { "tt-notify.breakdown-alert" }, true)
    storage.tt_alerts[#storage.tt_alerts + 1] = { player_index = player.index, entity = loco }
  end
end

--- A broken locomotive is back at full health: drop its alert.
---@param loco LuaEntity
function M.repaired(loco)
  local keep = {}
  for _, a in ipairs(storage.tt_alerts) do
    if a.entity == loco then
      local player = game.get_player(a.player_index)
      if player then player.remove_alert({ entity = loco, type = defines.alert_type.custom }) end
    else
      keep[#keep + 1] = a
    end
  end
  storage.tt_alerts = keep
  if loco.valid then
    for _, player in pairs(loco.force.connected_players) do
      if player.surface == loco.surface then
        player.create_local_flying_text({ text = { "tt-notify.repaired" }, position = loco.position, time_to_live = 180 })
      end
    end
  end
end

--- Drop expired custom alerts (every GOAL_TICK_INTERVAL).
function M.tick()
  local keep = {}
  for _, a in ipairs(storage.tt_alerts) do
    local player = game.get_player(a.player_index)
    if (a.expires and game.tick >= a.expires) or not a.entity.valid then
      if player and a.entity.valid then player.remove_alert({ entity = a.entity, type = defines.alert_type.custom }) end
    else
      keep[#keep + 1] = a
    end
  end
  storage.tt_alerts = keep
end

return M
