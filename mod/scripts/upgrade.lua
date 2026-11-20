-- Upgrade a city to its next tier in place (PLAN 2.1.3), when its construction port is
-- complete. The new tier gets its own port (or none at max tier), and the power city gets
-- its new generator.
local cities = require("scripts.cities")
local ports = require("scripts.ports")
local belt_ports = require("scripts.belt_ports")

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

  -- Forget the old record first, so on_object_destroyed does not tear down the new parts.
  storage.tt_cities[old_unit] = nil
  for _, key in ipairs({ "companion", "port" }) do
    if record[key] and record[key].valid then record[key].destroy() end
  end
  belt_ports.detach(record)
  old.destroy()

  local city = cities.place(target, surface, position, force)
  -- Keep the service pack credit and count. The bigger building (2.10) puts its service
  -- port elsewhere: the packs move to the new port and the old one goes. (Until 2.10.6
  -- moves service deliveries onto a port in the wall.)
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

  -- Open windows on the city or its old port follow the new city.
  for _, index in ipairs(viewers) do storage.tt_city_gui[index] = city end

  for _, fn in ipairs(after_hooks) do fn(old_name, city) end
  return city
end

ports.on_complete(M.upgrade)

return M
