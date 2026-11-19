-- 2.3.1: locomotive reliability (= health) wears down with driving.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local E = defines.direction.east
local X = 7000

--- Straight east-west line at y, `len` tiles long, with a fuelled locomotive near its start.
local function line(y, len, fuel)
  h.clear_area({ { X - 4, y - 6 }, { X + len + 4, y + 6 } })
  local rails = {}
  for x = X, X + len, 2 do
    rails[#rails + 1] = h.create("straight-rail", { x, y }, { direction = E })
  end
  local loco = h.create("locomotive", { X + 6, y }, { direction = E, raise_built = true })
  if fuel then assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 20 }) end
  return loco, rails
end

local function get(loco) return remote.call("tt-reliability", "get", loco) end

return {
  {
    name = "reliability: a driving locomotive loses about 7.5% per minute",
    fn = function(ctx)
      local loco, rails = line(-100, 1200, true)
      local schedule = assert(loco.train).get_schedule()
      schedule.add_record({ rail = rails[#rails], temporary = true, wait_conditions = {} })
      schedule.go_to_station(1)
      ctx:wait(600, function()
        assert_.truthy(math.abs(assert(loco.train).speed) > 0, "train is not moving")
        local lost = 1 - get(loco)
        -- 10 s of driving = 1.25%; allow for the poll's first visit and start-up
        assert_.truthy(lost > 0.008 and lost < 0.014, "lost " .. lost)
      end)
    end,
  },
  {
    name = "reliability: a standing locomotive does not wear",
    fn = function(ctx)
      local loco = line(-80, 40, true)
      ctx:wait(180, function()
        assert_.equals(get(loco), 1)
      end)
    end,
  },
  {
    name = "reliability: wear stops at 10%",
    fn = function()
      local loco = line(-60, 40, true)
      remote.call("tt-reliability", "set", loco, 0.12)
      remote.call("tt-reliability", "wear", loco, 3600 * 10)
      assert_.truthy(math.abs(get(loco) - 0.10) < 1e-6, "at " .. get(loco))
      remote.call("tt-reliability", "wear", loco, 3600)
      assert_.truthy(math.abs(get(loco) - 0.10) < 1e-6, "below the floor: " .. get(loco))
    end,
  },
  {
    name = "reliability: /tt-reliability is registered and its remote twin sets health",
    fn = function()
      assert_.truthy(commands.commands["tt-reliability"], "command missing")
      local loco = line(-40, 40, true)
      remote.call("tt-reliability", "set", loco, 0.5)
      assert_.truthy(math.abs(loco.health - 0.5 * loco.max_health) < 1e-6, "health " .. loco.health)
    end,
  },
}
