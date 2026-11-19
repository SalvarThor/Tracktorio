-- 2.4.3: refinery city (several fluid inputs and outputs, 2.4.2).
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local REFINERY = "tt-city-refinery"
local X = 8600

local function info(city) return remote.call("tt-city", "info", city) end

local function contains(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

--- An infinity pipe at `pos` keeping `fluid` full (supply) or empty (drain).
local function pipe(pos, fluid, supply)
  local p = h.create("infinity-pipe", pos)
  p.set_infinity_pipe_filter({ name = fluid, percentage = supply and 1 or 0, mode = "exactly" })
  return p
end

--- A powered refinery city centred at (x + 0.5, 0.5) with crude oil and water supplied.
local function rig(x)
  h.clear_area({ { x - 12, -12 }, { x + 14, 14 } })
  local city = h.place_city(REFINERY, { x + 0.5, 0.5 })
  pipe({ x - 1.5, 5.5 }, "crude-oil", true)
  pipe({ x + 2.5, 5.5 }, "water", true)
  h.test_power({ x + 8.5, 0.5 }, 4e6)
  return city
end

return {
  {
    name = "oil: refinery city tier 1 takes 40 crude + 28 water/s, makes 26 light oil + 22 gas/s at 0.95 MW",
    fn = function()
      local p = prototypes.entity[REFINERY]
      local r = p.fixed_recipe
      local per_s = p.get_crafting_speed() / r.energy
      local amounts = {}
      for _, i in ipairs(r.ingredients) do amounts[i.name] = i.amount * per_s end
      for _, o in ipairs(r.products) do amounts[o.name] = o.amount * per_s end
      assert_.equals(amounts["crude-oil"], 40)
      assert_.equals(amounts["water"], 28)
      assert_.equals(amounts["light-oil"], 26)
      assert_.equals(amounts["petroleum-gas"], 22)
      assert_.truthy(math.abs(p.get_max_energy_usage() * 60 - 0.95e6) < 1000, "power")
      for tier = 2, 3 do assert_.truthy(prototypes.entity[REFINERY .. "-t" .. tier], "tier " .. tier) end
    end,
  },
  {
    name = "oil: the window lists four pipe connections (crude and water in south, light and gas out north)",
    fn = function()
      h.clear_area({ { X - 12, -40 }, { X + 12, -20 } })
      local city = h.place_city(REFINERY, { X + 0.5, -29.5 })
      local c = info(city).connections
      assert_.equals(#c, 4, serpent.line(c))
      local by = {}
      for _, x in ipairs(c) do by[x.fluid] = x end
      assert_.equals(by["crude-oil"].side, "south"); assert_.equals(by["crude-oil"].offset, -2)
      assert_.equals(by["water"].side, "south"); assert_.equals(by["water"].offset, 2)
      assert_.equals(by["light-oil"].kind, "output"); assert_.equals(by["light-oil"].side, "north")
      assert_.equals(by["petroleum-gas"].kind, "output"); assert_.equals(by["petroleum-gas"].offset, 2)
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      assert_.truthy(assert(p.gui.screen["tt_city_frame"])["body"]["pipe-4"], "fourth pipe line missing")
      p.opened = nil
    end,
  },
  {
    name = "oil: refinery city runs on crude oil + water with both outputs drained",
    fn = function(ctx)
      local city = rig(X)
      pipe({ X - 1.5, -4.5 }, "light-oil", false)
      pipe({ X + 2.5, -4.5 }, "petroleum-gas", false)
      ctx:wait_until(function() return city.products_finished >= 3 end, 60 * 20, function()
        assert_.equals(info(city).status, "running")
      end)
    end,
  },
  {
    name = "oil: with no water it is starved and names water",
    fn = function(ctx)
      h.clear_area({ { X + 28, -12 }, { X + 54, 14 } })
      local x = X + 40
      local city = h.place_city(REFINERY, { x + 0.5, 0.5 })
      pipe({ x - 1.5, 5.5 }, "crude-oil", true)
      h.test_power({ x + 8.5, 0.5 }, 4e6)
      ctx:wait(120, function()
        local i = info(city)
        assert_.equals(i.status, "starved")
        assert_.truthy(contains(i.missing, "water"), serpent.line(i.missing))
      end)
    end,
  },
  {
    name = "oil: an undrained gas output stalls it, and the status names petroleum gas",
    fn = function(ctx)
      local city = rig(X + 80)
      pipe({ X + 80 - 1.5, -4.5 }, "light-oil", false) -- light oil drained, gas not
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 60, function()
        local full = info(city).full
        assert_.truthy(contains(full, "petroleum-gas"), serpent.line(full))
        assert_.falsy(contains(full, "light-oil"), "light oil is drained: " .. serpent.line(full))
      end)
    end,
  },
}
