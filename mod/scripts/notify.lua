-- Player-facing messages: chat with a map link (blocked map spots), and a check whether a
-- city's network looks too weak.
local city_defs = require("shared.city_defs")

local M = {}

--- Megawatts with up to two decimals and no trailing zeros ("0.95", "1.9", "21.6").
local function mw(watts)
  local s = string.format("%.2f", watts / 1e6):gsub("0+$", ""):gsub("%.$", "")
  return s
end

--- Steam per tick -> watts (165 C steam: 30 kJ/unit).
---@param usage number steam per tick
---@param temp number? steam temperature (default: the coal power city's)
local function generator_watts(usage, temp)
  return usage * 60 * city_defs.steam_joules(temp or city_defs.POWER_STEAM_TEMP)
end

--- What a city does: { per_min, product, draw (W)?, output (W)?, labs? }.
---@param entity_name string
function M.city_facts(entity_name)
  local proto = prototypes.entity[entity_name]
  local info = city_defs.by_entity[entity_name]
  local recipe = proto and proto.fixed_recipe
  local facts = {}
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
  if proto.electric_energy_source_prototype then facts.draw = proto.get_max_energy_usage() * 60 end
  if info.def.generator_usage then facts.output = generator_watts(info.def.generator_usage, info.def.steam_temp) end
  return facts
end

--- Power check for an electric city: nil if fine, else a localised warning.
--- Compares the max draw of all tracked cities on the same network with the output of the
--- power cities on it (other consumers like drills come on top).
---@param city LuaEntity
function M.network_warning(city)
  local facts = M.city_facts(city.name)
  if not facts.draw then return nil end
  if not city.is_connected_to_electric_network() then return { "tt-notify.not-connected" } end
  local net = city.electric_network_id
  local demand, supply = 0, 0
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid then
      local f = M.city_facts(e.name)
      if f.draw and e.electric_network_id == net then demand = demand + f.draw end
      if f.output and record.companion and record.companion.valid and record.companion.electric_network_id == net then
        supply = supply + f.output
      end
    end
  end
  -- playtest 2.10: "power cities on it make up to 0 MW" read as nonsense
  if supply <= 0 then return { "tt-notify.no-power-city", mw(demand) } end
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

--- A new lake's area on an extended map is taken by something the player built (2.6.1).
---@param surface LuaSurface
---@param position MapPosition
function M.lake_blocked(surface, position)
  ---@type any
  local message = { "tt-notify.lake-blocked",
    string.format("[gps=%d,%d,%s]", math.floor(position.x), math.floor(position.y), surface.name) }
  tell(game.forces["player"], message)
end

return M
