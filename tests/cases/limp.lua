-- 1.7: limp mode for fuel-empty locomotives.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local E = defines.direction.east
local LIMP_MAX = 1.2 * require("__tracktorio__/shared/config").LIMP_TOP_SPEED

--- Straight east-west line at y, from x0 for `len` tiles, and a locomotive near its start.
local function line(x0, y, len)
  h.clear_area({ { x0 - 4, y - 6 }, { x0 + len + 4, y + 6 } })
  local rails = {}
  for x = x0, x0 + len, 2 do
    rails[#rails + 1] = h.create("straight-rail", { x, y }, { direction = E })
  end
  local loco = h.create("locomotive", { x0 + 6, y }, { direction = E, raise_built = true })
  return loco, rails
end

local function limping(loco) return remote.call("tt-limp", "is_limping", loco) end

local function send_to(loco, rail)
  local train = assert(loco.train)
  local schedule = train.get_schedule()
  schedule.add_record({ rail = rail, temporary = true, wait_conditions = {} })
  schedule.go_to_station(1)
end

return {
  {
    name = "limp: a locomotive with no fuel limps at reduced top speed",
    fn = function()
      local loco = line(1300, -40, 40)
      remote.call("tt-limp", "check_all")
      assert_.truthy(limping(loco), "not limping")
      local max = assert(loco.train).max_forward_speed
      assert_.truthy(math.abs(max - LIMP_MAX) < 0.001, "max speed " .. max)
    end,
  },
  {
    name = "limp: the periodic poll picks up new locomotives by itself",
    fn = function(ctx)
      local loco = line(1300, -20, 40)
      ctx:wait(70, function()
        assert_.truthy(limping(loco), "poll did not apply limp mode")
      end)
    end,
  },
  {
    name = "limp: a limping train still drives to its destination, slowly",
    fn = function(ctx)
      local loco, rails = line(1300, 0, 200)
      remote.call("tt-limp", "check_all")
      send_to(loco, rails[#rails])
      local x0 = loco.position.x
      ctx:wait(60 * 10, function()
        local train = assert(loco.train)
        assert_.truthy(loco.position.x > x0 + 5, "did not move: " .. (loco.position.x - x0))
        assert_.truthy(math.abs(train.speed) <= LIMP_MAX + 0.0001, "too fast: " .. train.speed)
      end)
    end,
  },
  {
    name = "limp: refuelling with coal fuel ends limp mode",
    fn = function(ctx)
      local loco = line(1300, 20, 40)
      remote.call("tt-limp", "check_all")
      assert_.truthy(limping(loco), "not limping first")
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 5 })
      ctx:wait(70, function()
        assert_.falsy(limping(loco), "still limping after refuel")
        local max = assert(loco.train).max_forward_speed
        assert_.truthy(max > 1.1, "max speed " .. max)
      end)
    end,
  },
  {
    name = "limp: removed locomotives drop out of tracking",
    fn = function(ctx)
      local loco = line(1300, 60, 40)
      local before = remote.call("tt-limp", "tracked")
      loco.destroy()
      ctx:wait(70, function()
        assert_.equals(remote.call("tt-limp", "tracked"), before - 1, "tracked count")
      end)
    end,
  },
  {
    name = "limp: a fuelled locomotive is left alone",
    fn = function()
      local loco = line(1300, 40, 40)
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 5 })
      remote.call("tt-limp", "check_all")
      assert_.falsy(limping(loco), "fuelled loco set to limp")
    end,
  },
}
