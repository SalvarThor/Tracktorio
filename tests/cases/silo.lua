-- 2.5.6: rocket silo city.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local SILO = "tt-city-rocket-silo"
local X = 10000

local function status(city) return remote.call("tt-city", "silo_status", city) end

return {
  {
    name = "silo: the rocket silo city is a protected vanilla silo: 50 parts of 10 processing units + 10 LDS + 10 rocket fuel",
    fn = function()
      local p = prototypes.entity[SILO]
      assert_.equals(p.type, "rocket-silo")
      assert_.equals(p.rocket_parts_required, 50)
      assert_.falsy(p.mineable_properties.minable, "minable")
      local r = assert(p.fixed_recipe, "no fixed recipe")
      assert_.equals(r.name, SILO) -- own recipe (user: base-game amounts)
      local need = {}
      for _, i in ipairs(r.ingredients) do need[i.name] = i.amount end
      assert_.equals(need["processing-unit"], 10)
      assert_.equals(need["low-density-structure"], 10)
      assert_.equals(need["rocket-fuel"], 10)
      h.clear_area({ { X - 10, -50 }, { X + 12, -30 } })
      local city = h.place_city(SILO, { X + 0.5, -39.5 })
      assert_.falsy(city.operable or city.minable_flag or city.destructible, "not protected")
      assert_.truthy(remote.call("tt-city", "has_window", city), "no window")
      local pl = assert(game.players[1])
      remote.call("tt-city", "open_gui", pl.index, city)
      local line = assert(pl.gui.screen["tt_city_frame"])["body"]["silo"]
      assert_.truthy(line, "no rocket parts line")
      assert_.equals(line.caption[1], "tt-gui.silo-parts")
      pl.opened = nil
      assert_.falsy(remote.call("tt-city", "upgrade_status", city).next, "the silo has no next tier")
    end,
  },
  {
    name = "silo: a finished rocket launches by itself and is counted",
    fn = function(ctx)
      h.clear_area({ { X + 20, -12 }, { X + 44, 14 } })
      local city = h.place_city(SILO, { X + 30.5, 0.5 })
      h.test_power({ X + 38.5, 0.5 }, 6e6)
      local before = status(city).launched
      city.rocket_parts = 49
      city.insert({ name = "processing-unit", count = 10 })
      city.insert({ name = "low-density-structure", count = 10 })
      city.insert({ name = "rocket-fuel", count = 10 })
      ctx:wait_until(function() return status(city).launched > before end, 60 * 120, function()
        assert_.equals(status(city).launched, before + 1)
        assert_.equals(city.rocket_parts, 0)
      end)
    end,
  },
}
