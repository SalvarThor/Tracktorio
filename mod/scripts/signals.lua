-- City signal point (PLAN 2.11). A constant combinator in a city's door, in the middle of
-- its south wall (prototypes/signal_point.lua). Every second this module writes each item
-- and fluid the city holds (inputs, outputs, fuel; whole units), one status signal
-- (config.SIGNAL, value 1) and, while running, its speed. (2.15: the second point, for
-- what the next tier needed, went with the tiers.)
--
-- record.signal_points = { stock = LuaEntity }
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local port_layout = require("shared.port_layout")
local cities = require("scripts.cities")
local city_info = require("scripts.city_info")
local throttle = require("scripts.throttle")

local M = {}

--- Where the point sits, relative to the city's centre: the west tile of the door (even
--- sizes), or beside the middle tile (the 9x9 silo).
---@param size integer
local function door(size)
  local y = size / 2 - 0.5
  if size % 2 == 0 then return { -0.5, y } end
  return { -1, y }
end

---@param city LuaEntity
---@param name string
---@param offset number[]
local function create(city, name, offset)
  local e = city.surface.create_entity({
    name = name, position = { city.position.x + offset[1], city.position.y + offset[2] },
    force = city.force, create_build_effect_smoke = false,
  })
  if not e then return nil end
  cities.protect(e) -- not operable: the player wires it, there is nothing to set
  return e
end

--- Place a city's signal point (when the city is placed).
---@param city LuaEntity
---@param record table
function M.attach(city, record)
  local info = city_defs.by_entity[city.name]
  if not info then return end
  record.signal_points = { stock = create(city, config.SIGNAL_POINT, door(port_layout.size(info.def))) }
  M.update(record)
end

--- The player's wires on a city's signal points: { [kind] = { { owner, target_id, id }, ... } }.
---@param record table
function M.save_wires(record)
  local out = {}
  for kind, point in pairs(record.signal_points or {}) do
    if point.valid then
      local list = {}
      for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
        local connector = point.get_wire_connector(id, false)
        for _, c in ipairs(connector and connector.connections or {}) do
          if c.origin == defines.wire_origin.player then
            list[#list + 1] = { owner = c.target.owner, target_id = c.target.wire_connector_id, id = id }
          end
        end
      end
      out[kind] = list
    end
  end
  return out
end

--- Reconnect saved wires to a record's new points (after the upgrade planner swapped the
--- city for its later kind). A wire to something that is gone is dropped.
---@param record table
---@param saved table
function M.restore_wires(record, saved)
  for kind, list in pairs(saved or {}) do
    local point = record.signal_points and record.signal_points[kind]
    if point and point.valid then
      for _, w in ipairs(list) do
        if w.owner.valid then
          local target = w.owner.get_wire_connector(w.target_id, true)
          point.get_wire_connector(w.id, true).connect_to(target, true)
        end
      end
    end
  end
end

--- Remove a city's points.
---@param record table
function M.detach(record)
  for _, point in pairs(record.signal_points or {}) do
    if point.valid then point.destroy() end
  end
  record.signal_points = nil
end

local STATUS = {
  [defines.entity_status.working] = config.SIGNAL.running,
  [defines.entity_status.low_power] = config.SIGNAL.running,
  [defines.entity_status.no_power] = config.SIGNAL.no_power,
  [defines.entity_status.full_output] = config.SIGNAL.output_full,
  [defines.entity_status.missing_science_packs] = config.SIGNAL.starved,
}

--- Write a point's signals: `signals` = { ["item/iron-plate"] = count, ... }.
---@param point LuaEntity
---@param signals table
local function write(point, signals)
  local cb = point.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
  local section = cb.get_section(1) or cb.add_section()
  if not section then return end
  local keys = {}
  for key in pairs(signals) do keys[#keys + 1] = key end
  table.sort(keys) -- a stable order, so the combinator's window doesn't shuffle
  local filters = {}
  for _, key in ipairs(keys) do
    local count = math.floor(signals[key])
    if count ~= 0 then
      local kind, name = key:match("^([^/]+)/(.+)$")
      -- 2.1: every signal carries a quality; without one a filter sends nothing
      local value = { type = kind, name = name, quality = "normal" }
      filters[#filters + 1] = { value = value, min = count }
    end
  end
  section.filters = filters
end

---@param signals table
---@param inv LuaInventory?
local function add_inventory(signals, inv)
  if not inv then return end
  for _, c in ipairs(inv.get_contents()) do
    local key = "item/" .. c.name
    signals[key] = (signals[key] or 0) + c.count
  end
end

--- Rewrite a city's signals now.
---@param record table
function M.update(record)
  local points = record.signal_points
  local city = record.entity
  if not (points and city and city.valid) then return end
  local stock = points.stock
  if stock and stock.valid then
    local signals = {}
    if city.type == "lab" then
      add_inventory(signals, city.get_inventory(defines.inventory.lab_input))
    else
      add_inventory(signals, city.get_inventory(defines.inventory.crafter_input))
      add_inventory(signals, city.get_inventory(defines.inventory.crafter_output))
      add_inventory(signals, city.get_fuel_inventory())
      for i = 1, city.fluids_count do -- 2.1: no LuaEntity.fluidbox
        local f = city.get_fluid(i)
        if f then signals["fluid/" .. f.name] = (signals["fluid/" .. f.name] or 0) + f.amount end
      end
    end
    if city.type == "rocket-silo" then signals["item/rocket-part"] = city.rocket_parts end
    local status = city.status
    local s = status and (STATUS[status] or (city_info.STARVED[status] and config.SIGNAL.starved))
    if s then signals["virtual/" .. s] = 1 end
    if s == config.SIGNAL.running then signals["virtual/" .. config.SIGNAL.speed] = throttle.percent(record) end
    write(stock, signals)
  end
end

--- Every second (control.lua).
function M.tick()
  for _, record in pairs(storage.tt_cities or {}) do M.update(record) end
end

cities.on_any_placed(M.attach)

return M
