-- Construction ports (PLAN 2.1.2). Every city with a higher tier gets a fixed 1x1 port on the
-- tile west of its top-left corner. Once a second the script counts and removes what the
-- port holds into the city's upgrade progress; slot filters list only what the next tier
-- still needs. Materials never enter the city.
--
-- record.upgrade = { target = <entity name of the next tier>, tier = n,
--                    cost = { [item] = count }, delivered = { [item] = count }, complete = bool }
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")

local M = {}

--- Tile centre of the port for a city: west of the city's top-left tile.
---@param city LuaEntity
function M.port_position(city)
  local box = city.bounding_box
  return { x = math.floor(box.left_top.x) - 0.5, y = math.floor(box.left_top.y) + 0.5 }
end

--- Fresh progress table towards the next tier, or nil at max tier.
---@param city_name string
local function new_upgrade(city_name)
  local target, tier_def = city_defs.next_tier(city_name)
  if not (target and tier_def) then return nil end
  local cost, delivered = {}, {}
  for _, c in ipairs(tier_def.cost) do
    cost[c.name] = c.count
    delivered[c.name] = 0
  end
  local tier = assert(city_defs.by_entity[target], "tt: unknown tier " .. target).tier
  return { target = target, tier = tier, cost = cost, delivered = delivered, complete = false }
end
M.new_upgrade = new_upgrade

--- Items the port should still accept, in a stable order.
---@param upgrade table?
local function still_needed(upgrade)
  local out = {}
  if not upgrade or upgrade.complete then return out end
  for item, need in pairs(upgrade.cost) do
    if upgrade.delivered[item] < need then out[#out + 1] = item end
  end
  table.sort(out)
  return out
end

---@param record table
local function set_filters(record)
  local port = record.port
  if not (port and port.valid) then return end
  local inv = assert(port.get_inventory(defines.inventory.chest))
  local needed = still_needed(record.upgrade)
  for i = 1, #inv do
    local name = #needed > 0 and needed[(i - 1) % #needed + 1] or config.PORT_CLOSED_ITEM
    local current = inv.get_filter(i)
    if not current or current.name ~= name then inv.set_filter(i, { name = name }) end
  end
end

--- Place the port for a city (if it has a next tier and no port yet).
---@param city LuaEntity
---@param record table
function M.attach(city, record)
  if record.port and record.port.valid then return end
  if not city_defs.next_tier(record.name) then return end
  local port = city.surface.create_entity({
    name = config.PORT, position = M.port_position(city), force = city.force, create_build_effect_smoke = false })
  assert(port, "tt: could not place a construction port for " .. record.name)
  cities.protect(port)
  record.port = port
  record.upgrade = record.upgrade or new_upgrade(record.name)
  set_filters(record)
end

cities.on_any_placed(M.attach)

--- Fraction of the upgrade delivered (0..1), counting each material up to its cost.
---@param upgrade table?
function M.progress(upgrade)
  if not upgrade then return 1 end
  local got, need = 0, 0
  for item, n in pairs(upgrade.cost) do
    need = need + n
    got = got + math.min(n, upgrade.delivered[item])
  end
  return need > 0 and got / need or 1
end

-- Called once per port tick for each city whose upgrade just completed (2.1.3 swaps it).
local on_complete = nil
---@param fn fun(record: table)
function M.on_complete(fn) on_complete = fn end

--- Empty every port into its city's progress (every GOAL_TICK_INTERVAL ticks). Completed
--- upgrades run after the loop: they replace entries of storage.tt_cities.
function M.tick()
  local completed = {}
  for _, record in pairs(storage.tt_cities) do
    local port, upgrade = record.port, record.upgrade
    if port and port.valid and upgrade and not upgrade.complete then
      local inv = assert(port.get_inventory(defines.inventory.chest))
      for item in pairs(upgrade.cost) do
        local n = inv.get_item_count(item)
        if n > 0 then
          inv.remove({ name = item, count = n })
          upgrade.delivered[item] = upgrade.delivered[item] + n
        end
      end
      if M.progress(upgrade) >= 1 then
        upgrade.complete = true
        completed[#completed + 1] = record
      end
      set_filters(record)
    end
  end
  if on_complete then
    for _, record in ipairs(completed) do on_complete(record) end
  end
end

--- Upgrade status of a city, for the UI and tests.
---@param city LuaEntity
function M.status(city)
  local record = storage.tt_cities[city.unit_number]
  if not record then return nil end
  local info = city_defs.by_entity[record.name]
  local upgrade = record.upgrade
  return {
    tier = info and info.tier or 1,
    max_tier = info and info.max_tier or 1,
    next = upgrade and upgrade.target or nil,
    cost = upgrade and upgrade.cost or {},
    delivered = upgrade and upgrade.delivered or {},
    complete = upgrade and upgrade.complete or false,
    progress = M.progress(upgrade),
    port = record.port,
  }
end

return M
