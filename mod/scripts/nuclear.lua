-- Nuclear power city runs flat out (playtest 2.6.6, user): like a vanilla reactor it can't
-- throttle. With fuel in, it burns at its full rate whether the power is used or not; the
-- steam nobody draws is vented. A burner city only burns while crafting, so venting keeps it
-- crafting. Checked every GOAL_TICK_INTERVAL (1 s): the steam output holds VOLUME, far more
-- than a tier 3 city makes in a second, so it never backs up between checks.
local city_defs = require("shared.city_defs")

local M = {}

M.VOLUME = 4000 -- steam output box of the nuclear city (shared/city_defs.lua)
M.VENT_ABOVE = 1000 -- steam above this is vented...
M.KEEP = 400 -- ...down to this, a buffer for the generator

--- Is this a city that burns fuel flat out (the nuclear city, any tier)?
---@param name string entity name
function M.is_flat_out(name)
  local info = city_defs.by_entity[name]
  return info ~= nil and info.def.burner ~= nil
end

--- Vent unused steam from every nuclear city. Returns the steam vented (for tests).
function M.tick()
  local vented = 0
  for _, record in pairs(storage.tt_cities) do
    local city = record.entity ---@type LuaEntity
    if city.valid and M.is_flat_out(city.name) then
      -- 2.1: remove_fluid(storage index, amount); the steam output is one of the storages
      for i = 1, city.fluids_count do
        local f = city.get_fluid(i)
        if f and f.name == "steam" and f.amount > M.VENT_ABOVE then
          local removed = city.remove_fluid(i, f.amount - M.KEEP)
          vented = vented + (removed and removed.amount or 0)
        end
      end
    end
  end
  return vented
end

--- Share of its full output the city's generator put out last tick (0..1), or nil.
---@param record table
function M.power_use(record)
  local gen = record.companion
  if not (gen and gen.valid) then return nil end
  local max = gen.prototype.get_max_energy_production()
  if not max or max <= 0 then return nil end
  return math.min(1, gen.energy_generated_last_tick / max)
end

return M
