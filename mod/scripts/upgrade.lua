-- Upgrade a city to its next tier in place (PLAN 2.1.3), when its construction port is
-- complete. The new tier gets its own port (or none at max tier), and the power city gets
-- its new generator.
local cities = require("scripts.cities")
local ports = require("scripts.ports")

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

  -- Forget the old record first, so on_object_destroyed does not tear down the new parts.
  storage.tt_cities[old_unit] = nil
  for _, key in ipairs({ "companion", "port" }) do
    if record[key] and record[key].valid then record[key].destroy() end
  end
  old.destroy()

  local city = cities.place(target, surface, position, force)
  -- The service port stayed (the new tier adopted it); keep its pack credit and count.
  local new_record = storage.tt_cities[city.unit_number]
  if record.service and new_record then new_record.service = record.service end

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

  -- Open windows on the city or its old port follow the new city.
  for _, index in ipairs(viewers) do storage.tt_city_gui[index] = city end

  for _, fn in ipairs(after_hooks) do fn(old_name, city) end
  return city
end

ports.on_complete(M.upgrade)

return M
