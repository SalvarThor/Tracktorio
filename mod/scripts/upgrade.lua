-- Upgrade a city to its next tier in place (PLAN 2.1.3), when its construction port is
-- complete. The new tier gets its own port (or none at max tier), and the power city gets
-- its new generator.
local cities = require("scripts.cities")
local ports = require("scripts.ports")
local belt_ports = require("scripts.belt_ports")
local city_defs = require("shared.city_defs")
local port_layout = require("shared.port_layout")

local M = {}

-- Called after a successful upgrade with (old_name, new_entity) (notifications, 2.1.4).
local after_hooks = {}
---@param fn fun(old_name: string, city: LuaEntity)
function M.on_upgraded(fn) after_hooks[#after_hooks + 1] = fn end

--- Items in an inventory as a list of stacks (name, count, quality).
---@param inv LuaInventory?
local function contents(inv)
  local out = {}
  if inv then
    for _, c in ipairs(inv.get_contents()) do out[#out + 1] = { name = c.name, count = c.count, quality = c.quality } end
  end
  return out
end

--- The connected player of `force` nearest to `position`, or nil.
---@param force LuaForce
---@param position MapPosition
local function nearest_player(force, position)
  local best, best_d
  for _, player in pairs(force.connected_players) do
    local p = player.position
    local d = (p.x - position.x) ^ 2 + (p.y - position.y) ^ 2
    if not best_d or d < best_d then best, best_d = player, d end
  end
  return best
end

--- Make room for the bigger building (2.10.7). What the player built inside its footprint
--- is mined and goes to the nearest player of the city's force (what doesn't fit, or with
--- no player online, is spilled south of the building); characters there step outside.
--- Mod entities (the city, its ports and hidden chests) are left for the swap. Returns the
--- player things went to, if any.
---@param old LuaEntity
---@param size integer the new building's size
local function clear_footprint(old, size)
  local c, surface, half = old.position, old.surface, size / 2
  local area = { { c.x - half, c.y - half }, { c.x + half, c.y + half } }
  local edge = { x = c.x, y = c.y + half + 1.5 }
  local player = nearest_player(old.force --[[@as LuaForce]], c)
  local buffer = game.create_inventory(1000)
  for _, e in pairs(surface.find_entities_filtered({ area = area })) do
    if e.valid and string.sub(e.name, 1, 3) ~= "tt-" then
      if e.type == "character" then
        e.teleport(surface.find_non_colliding_position("character", edge, 32, 0.5) or edge)
      elseif e.force == old.force and e.type ~= "item-entity" then
        e.mine({ inventory = buffer, force = true, raise_destroyed = true })
      end
    end
  end
  for _, stack in ipairs(buffer.get_contents()) do
    local left = stack.count
    if player then left = left - player.insert({ name = stack.name, count = left, quality = stack.quality }) end
    if left > 0 then
      surface.spill_item_stack({ position = edge, stack = { name = stack.name, count = left, quality = stack.quality },
        enable_looted = true, allow_belts = false })
    end
  end
  buffer.destroy()
  return player
end

--- Replace the record's city with its next tier. Returns the new entity, or nil.
---@param record table
function M.upgrade(record)
  local old = record.entity
  local target = record.upgrade and record.upgrade.target
  if not (old and old.valid and target) then return nil end
  local surface, position, force, old_name = old.surface, old.position, old.force, record.name
  local old_unit = old.unit_number
  local port_pos = record.port and record.port.valid and record.port.position or ports.port_position(old)

  -- Windows showing this city or its port, to re-point after the swap.
  local viewers = {}
  for index, shown in pairs(storage.tt_city_gui or {}) do
    if shown == old or (record.port and shown == record.port) then viewers[#viewers + 1] = index end
  end

  local in_id = old.type == "lab" and defines.inventory.lab_input or defines.inventory.crafter_input
  local inputs = contents(old.get_inventory(in_id))
  local outputs = old.type == "lab" and {} or contents(old.get_inventory(defines.inventory.crafter_output))
  -- Burner cities (nuclear, 2.6.4): the fuel and what is left of the cell burning now.
  local fuel = contents(old.get_fuel_inventory())
  local burner = old.burner
  local burning = burner and burner.currently_burning
  local burning_left = burner and burner.remaining_burning_fuel or 0

  -- The bigger building's footprint is cleared before the swap (2.10.7).
  local target_info = city_defs.by_entity[target]
  local size = target_info and port_layout.size(target_info.def, target_info.tier) or old.prototype.tile_width
  local player = size > old.prototype.tile_width and clear_footprint(old, size) or nil

  -- Forget the old record first, so on_object_destroyed does not tear down the new parts.
  storage.tt_cities[old_unit] = nil
  for _, key in ipairs({ "companion", "port" }) do
    if record[key] and record[key].valid then record[key].destroy() end
  end
  belt_ports.detach(record)
  old.destroy()

  local city = cities.place(target, surface, position, force)
  -- Keep the service pack credit and count. The bigger building (2.10) has its hidden
  -- service chest further out: the packs move to the new chest and the old one goes.
  local new_record = storage.tt_cities[city.unit_number]
  if record.service and new_record then new_record.service = record.service end
  local old_service = record.service_port
  if old_service and old_service.valid and new_record and new_record.service_port ~= old_service then
    local to = new_record.service_port and new_record.service_port.valid and new_record.service_port.get_inventory(defines.inventory.chest)
    for _, stack in ipairs(contents(old_service.get_inventory(defines.inventory.chest))) do
      local inserted = to and to.insert(stack) or 0
      if inserted < stack.count then
        surface.spill_item_stack({ position = old_service.position, stack = { name = stack.name, count = stack.count - inserted, quality = stack.quality },
          enable_looted = true, allow_belts = false })
      end
    end
    old_service.destroy()
  end

  -- Restore contents. What the new recipe can't take (coal after going electric) is spilled
  -- beside the port, for the player to pick up.
  local input_inv = city.get_inventory(in_id)
  for _, stack in ipairs(inputs) do
    local inserted = input_inv and input_inv.insert(stack) or 0
    if inserted < stack.count then
      surface.spill_item_stack({ position = port_pos, stack = { name = stack.name, count = stack.count - inserted, quality = stack.quality },
        enable_looted = true, allow_belts = false })
    end
  end
  local output_inv = city.type ~= "lab" and city.get_inventory(defines.inventory.crafter_output) or nil
  for _, stack in ipairs(outputs) do
    local inserted = output_inv and output_inv.insert(stack) or 0
    if inserted < stack.count then
      surface.spill_item_stack({ position = port_pos, stack = { name = stack.name, count = stack.count - inserted, quality = stack.quality },
        enable_looted = true, allow_belts = false })
    end
  end

  local fuel_inv = city.get_fuel_inventory()
  for _, stack in ipairs(fuel) do
    local inserted = fuel_inv and fuel_inv.insert(stack) or 0
    if inserted < stack.count then
      surface.spill_item_stack({ position = port_pos, stack = { name = stack.name, count = stack.count - inserted, quality = stack.quality },
        enable_looted = true, allow_belts = false })
    end
  end
  if burning and city.burner and burning_left > 0 then
    -- 2.1: writing currently_burning needs remaining_burning_fuel set right after
    city.burner.currently_burning = burning
    city.burner.remaining_burning_fuel = burning_left
  end

  -- Inserters the bigger building now reaches go back too (2.10.5).
  if player or size > old.prototype.tile_width then
    local box = city.bounding_box
    for _, ins in pairs(surface.find_entities_filtered({ type = "inserter",
      area = { { box.left_top.x - 3, box.left_top.y - 3 }, { box.right_bottom.x + 3, box.right_bottom.y + 3 } } })) do
      belt_ports.check_inserter(ins, player and player.index)
    end
  end

  -- Open windows on the city or its old port follow the new city.
  for _, index in ipairs(viewers) do storage.tt_city_gui[index] = city end

  for _, fn in ipairs(after_hooks) do fn(old_name, city) end
  return city
end

ports.on_complete(M.upgrade)

return M
