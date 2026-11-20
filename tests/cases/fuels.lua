-- 2.4.1: solid fuel and rocket fuel in locomotives, with their vanilla stats.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local E = defines.direction.east
local X = 7800

--- A 600-tile line at y with a locomotive burning `fuel`, sent to the far end.
local function racer(y, fuel)
  h.clear_area({ { X - 4, y - 4 }, { X + 604, y + 4 } })
  local rails = {}
  for x = X, X + 600, 2 do rails[#rails + 1] = h.create("straight-rail", { x, y }, { direction = E }) end
  local loco = h.create("locomotive", { X + 6, y }, { direction = E, raise_built = true })
  assert(loco.get_fuel_inventory()).insert({ name = fuel, count = 5 })
  local schedule = assert(loco.train).get_schedule()
  schedule.add_record({ rail = rails[#rails], temporary = true, wait_conditions = {} })
  schedule.go_to_station(1)
  return loco
end

return {
  {
    name = "fuels: solid and rocket fuel keep vanilla stats and also burn in burner entities",
    fn = function()
      local solid, rocket = prototypes.item["solid-fuel"], prototypes.item["rocket-fuel"]
      assert_.equals(solid.fuel_value, 12e6)
      assert_.equals(rocket.fuel_value, 100e6)
      assert_.equals(solid.fuel_acceleration_multiplier, 1.2)
      assert_.equals(rocket.fuel_top_speed_multiplier, 1.15)
      for _, item in ipairs({ solid, rocket }) do
        local cats = {}
        for _, c in ipairs(item.fuel_categories or {}) do cats[c] = true end -- 2.1: an array of names
        assert_.truthy(cats["chemical"] and cats["tt-locomotive"], item.name .. " categories: " .. serpent.line(item.fuel_categories))
      end
    end,
  },
  {
    name = "fuels: on a real train, rocket fuel beats solid fuel beats coal fuel (speed and acceleration)",
    fn = function(ctx)
      local coal, solid, rocket = racer(500, "tt-coal-fuel"), racer(510, "solid-fuel"), racer(520, "rocket-fuel")
      ctx:wait(300, function()
        local function max(l) return assert(l.train).max_forward_speed end
        assert_.truthy(math.abs(max(coal) - 1.2) < 0.001, "coal max " .. max(coal))
        assert_.truthy(math.abs(max(solid) - 1.2 * 1.05) < 0.001, "solid max " .. max(solid))
        assert_.truthy(math.abs(max(rocket) - 1.2 * 1.15) < 0.001, "rocket max " .. max(rocket))
        local function speed(l) return math.abs(assert(l.train).speed) end
        assert_.truthy(speed(solid) > speed(coal) and speed(rocket) > speed(solid),
          string.format("speeds after 5 s: coal %.3f solid %.3f rocket %.3f", speed(coal), speed(solid), speed(rocket)))
      end)
    end,
  },
  {
    name = "fuels: a locomotive that runs out of solid fuel limps, and refuelling with it ends limp mode",
    fn = function(ctx)
      h.clear_area({ { X - 4, 536 }, { X + 64, 544 } })
      for x = X, X + 60, 2 do h.create("straight-rail", { x, 540 }, { direction = E }) end
      local loco = h.create("locomotive", { X + 6, 540 }, { direction = E, raise_built = true })
      remote.call("tt-limp", "check_all")
      assert_.truthy(remote.call("tt-limp", "is_limping", loco), "not limping")
      assert(loco.get_fuel_inventory()).insert({ name = "solid-fuel", count = 5 })
      ctx:wait(70, function()
        assert_.falsy(remote.call("tt-limp", "is_limping", loco), "still limping")
      end)
    end,
  },
}
