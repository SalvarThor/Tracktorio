-- 2.12: the throttle. A hidden beacon in a city with modules that take 5% off speed and
-- power each, set by script so a steady input gives a steady city.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local X = 48000

---@param city LuaEntity
---@param steps integer
local function beacon_in(city, steps)
  local b = h.create("tt-throttle-beacon", city.position)
  if steps > 0 then
    assert(b.get_inventory(defines.inventory.beacon_modules)).insert({ name = "tt-throttle-module", count = steps })
  end
  return b
end

return {
  {
    -- 2.12.1 spike
    name = "throttle spike: a beacon's modules slow its city's speed and power together, 5% each, floor 20%",
    fn = function(ctx)
      local x = X
      h.clear_area({ { x - 12, -12 }, { x + 12, 12 } })
      local city = h.place_city("tt-city-depot", { x + 0.5, 0.5 })
      local base = city.crafting_speed
      local beacon = beacon_in(city, 10)
      ctx:wait(2, function()
        local e = city.effects or {}
        assert_.truthy(math.abs((e.speed or 0) + 0.5) < 1e-6, "speed effect " .. serpent.line(e))
        assert_.truthy(math.abs((e.consumption or 0) + 0.5) < 1e-6, "consumption effect " .. serpent.line(e))
        assert_.truthy(math.abs(city.crafting_speed - base * 0.5) < 1e-6, "crafting speed " .. city.crafting_speed .. " of " .. base)
        local inv = assert(beacon.get_inventory(defines.inventory.beacon_modules))
        inv.clear()
        inv.insert({ name = "tt-throttle-module", count = 16 })
        ctx:wait(2, function()
          assert_.truthy(math.abs(city.crafting_speed - base * 0.2) < 1e-6, "crafting speed at 16 steps " .. city.crafting_speed)
        end)
      end)
    end,
  },
  {
    name = "throttle spike: the beacon reaches nothing outside its city (a drill at the wall keeps full speed)",
    fn = function(ctx)
      local x = X + 100
      h.clear_area({ { x - 12, -12 }, { x + 12, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      local e = h.edges(city)
      local drill = h.create("electric-mining-drill", { e.right + 1, 0.5 })
      local inserter = h.create("assembling-machine-1", { x + 0.5, e.bottom + 1.5 })
      beacon_in(city, 16)
      ctx:wait(2, function()
        local function none(entity)
          local fx = entity.effects
          return fx == nil or ((fx.speed or 0) == 0 and (fx.consumption or 0) == 0)
        end
        assert_.falsy(none(city), "the city is not slowed")
        assert_.truthy(none(drill), "the drill is slowed: " .. serpent.line(drill.effects))
        assert_.truthy(none(inserter), "the machine below the wall is slowed: " .. serpent.line(inserter.effects))
      end)
    end,
  },
}
