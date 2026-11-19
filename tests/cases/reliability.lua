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
local function limping(loco) return remote.call("tt-limp", "is_limping", loco) end
local function broken(loco) return remote.call("tt-reliability", "is_broken", loco) end
local LIMP_MAX = 1.2 * 0.10

local function mentions(ls, key)
  if type(ls) ~= "table" then return false end
  if ls[1] == key then return true end
  for _, v in pairs(ls) do if mentions(v, key) then return true end end
  return false
end

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
  {
    name = "breakdown: chance is zero when new and ~1.1% per second at 25%",
    fn = function()
      assert_.equals(remote.call("tt-reliability", "chance", 1, 60), 0)
      local c = remote.call("tt-reliability", "chance", 0.25, 60)
      assert_.truthy(math.abs(c - 0.01125) < 1e-6, "chance " .. c)
      local half = remote.call("tt-reliability", "chance", 0.5, 60)
      assert_.truthy(half < c and half > 0, "50% chance " .. half)
    end,
  },
  {
    name = "breakdown: one broken locomotive makes its whole fuelled train limp, with a message",
    fn = function()
      local front = line(0, 60, true)
      local back = h.create("locomotive", { X + 13, 0 }, { direction = E, raise_built = true })
      assert(back.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 20 })
      local train = assert(front.train)
      assert_.equals(#train.carriages, 2, "locomotives not coupled")
      local since = game.tick
      remote.call("tt-reliability", "break_down", back)
      remote.call("tt-limp", "check_all")
      assert_.truthy(limping(front) and limping(back), "both locomotives should limp")
      assert_.truthy(math.abs(train.max_forward_speed - LIMP_MAX) < 0.001, "max speed " .. train.max_forward_speed)
      local found = false
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if m.tick >= since and mentions(m.message, "tt-notify.breakdown") then found = true end
      end
      assert_.truthy(found, "no breakdown message")
    end,
  },
  {
    name = "breakdown: repairing to full health cures it and the train runs at full speed",
    fn = function(ctx)
      local loco = line(20, 60, true)
      remote.call("tt-reliability", "set", loco, 0.5)
      remote.call("tt-reliability", "break_down", loco)
      remote.call("tt-limp", "check_all")
      assert_.truthy(limping(loco), "not limping")
      local alerts = remote.call("tt-city", "alerts_pending")
      assert_.truthy(alerts > 0, "no breakdown alert")
      loco.health = loco.max_health -- what a repair pack does
      ctx:wait(130, function()
        assert_.falsy(broken(loco), "still broken")
        assert_.truthy(remote.call("tt-city", "alerts_pending") < alerts, "breakdown alert not cleared")
        assert_.falsy(limping(loco), "still limping")
        assert_.truthy(assert(loco.train).max_forward_speed > 1.1, "max speed " .. assert(loco.train).max_forward_speed)
      end)
    end,
  },
  {
    name = "breakdown: a part repair is not enough",
    fn = function(ctx)
      local loco = line(40, 60, true)
      remote.call("tt-reliability", "set", loco, 0.3)
      remote.call("tt-reliability", "break_down", loco)
      remote.call("tt-reliability", "set", loco, 0.9)
      ctx:wait(130, function()
        assert_.truthy(broken(loco) and limping(loco), "cured below full health")
      end)
    end,
  },
  {
    name = "breakdown: fuel-empty limp and a breakdown don't fight",
    fn = function(ctx)
      local loco = line(60, 60, false)
      remote.call("tt-reliability", "set", loco, 0.5)
      remote.call("tt-reliability", "break_down", loco)
      remote.call("tt-limp", "check_all")
      assert_.truthy(limping(loco), "not limping")
      -- refuelling alone does not cure a breakdown
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 5 })
      ctx:wait(70, function()
        assert_.truthy(limping(loco), "refuelling ended a breakdown")
        loco.health = loco.max_health
        ctx:wait(130, function()
          assert_.falsy(limping(loco), "repaired and fuelled, still limping")
        end)
      end)
    end,
  },
}