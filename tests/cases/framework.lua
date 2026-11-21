-- 2.2.1: every city definition works from its data alone (no per-city code): each kind
-- exists and opens a window, and every Tracktorio prototype has a locale name.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local defs = require("__tracktorio__/shared/city_defs")

local X = 4400

local function info(city) return remote.call("tt-city", "info", city) end

return {
  {
    name = "framework: every city kind is 12x12 (the silo 9x9) and has a window and recipe or lab info",
    fn = function()
      h.clear_area({ { X - 20, -30 }, { X + 20, 30 } })
      for _, def in ipairs(defs.list) do
        local name = defs.entity_name(def.name)
        local city = h.place_city(name, { X + 0.5, 0.5 })
        assert_.equals(h.city_size(name), def.kind == "silo" and 9 or 12, name .. " size")
        assert_.truthy(remote.call("tt-city", "has_window", city), name .. ": no window")
        assert_.truthy(info(city).recipe or info(city).lab, name .. ": no recipe or lab info")
        city.destroy()
      end
    end,
  },
  {
    name = "framework: every Tracktorio prototype has a locale name",
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
