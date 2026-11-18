-- 2.2.1: every city definition works from its data alone (no per-city code): each tier
-- exists, opens a window, has pips and (below max tier) a port, and every Train Tycoon
-- prototype has a locale name.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")
local defs = require("__train-tycoon__/shared/city_defs")

local X = 4400

local function info(city) return remote.call("tt-city", "info", city) end

return {
  {
    name = "framework: every tier of every city has a window, pips and a port below max tier",
    fn = function()
      h.clear_area({ { X - 20, -30 }, { X + 20, 30 } })
      for _, def in ipairs(defs.list) do
        for tier = 1, #def.tiers do
          local name = defs.entity_name(def.name, tier)
          local city = h.place_city(name, { X + 0.5, 0.5 })
          assert_.truthy(remote.call("tt-city", "has_window", city), name .. ": no window")
          local m = assert(remote.call("tt-city", "tier_marks", city), name .. ": no pips")
          assert_.equals(m.filled, tier, name .. " pips")
          assert_.equals(m.total, #def.tiers, name .. " pips")
          local s = assert(remote.call("tt-city", "upgrade_status", city))
          assert_.equals(s.tier, tier, name .. " tier")
          if tier < #def.tiers then
            assert_.truthy(s.port and s.port.valid, name .. ": no port")
            for _, c in ipairs(def.tiers[tier + 1].cost) do
              assert_.equals(s.cost[c.name], c.count, name .. " cost " .. c.name)
              assert_.truthy(prototypes.item[c.name], name .. ": unknown cost item " .. c.name)
            end
          else
            assert_.truthy(not (s.port and s.port.valid), name .. ": max tier has a port")
          end
          assert_.truthy(info(city).recipe or info(city).lab, name .. ": no recipe or lab info")
          if s.port and s.port.valid then s.port.destroy() end -- the destroy event is a tick late
          city.destroy()
        end
      end
    end,
  },
  {
    name = "framework: an idle power city at tier 2 says no power demand, not output full",
    fn = function(ctx)
      h.clear_area({ { X - 20, 40 }, { X + 20, 70 } })
      local city = h.place_city("tt-city-power-t2", { X + 0.5, 50.5 })
      city.insert({ name = "coal", count = 40 })
      local pipe = h.create("infinity-pipe", { X + 0.5, 55.5 })
      pipe.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "exactly", temperature = 15 })
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 60, function()
        local p = assert(game.players[1])
        remote.call("tt-city", "open_gui", p.index, city)
        local status = assert(p.gui.screen["tt_city_frame"])["body"]["status"]
        assert_.equals(status.caption[1], "tt-gui.city-status-power-idle")
        p.opened = nil
      end)
    end,
  },
  {
    name = "framework: every Train Tycoon prototype has a locale name",
    fn = function(ctx)
      local p = assert(game.players[1])
      local pending = {}
      local function ask(kind, proto)
        local id = p.request_translation(proto.localised_name)
        if id then pending[id] = kind .. " " .. proto.name end
      end
      for _, kind in ipairs({ "entity", "item", "recipe", "technology", "fluid" }) do
        for name, proto in pairs(prototypes[kind]) do
          if string.sub(name, 1, 3) == "tt-" then ask(kind, proto) end
        end
      end
      assert_.truthy(next(pending), "nothing to translate")
      ctx:wait_until(function()
        for id in pairs(pending) do if not h.translations[id] then return false end end
        return true
      end, 600, function()
        local missing = {}
        for id, what in pairs(pending) do
          if not h.translations[id].translated then missing[#missing + 1] = what end
        end
        table.sort(missing)
        assert_.equals(#missing, 0, "no locale: " .. table.concat(missing, ", "))
      end)
    end,
  },
}
