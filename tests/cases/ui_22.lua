-- 2.2.7: UI for the intermediate cities and the research complex.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local X = 5600

local function mentions(ls, key)
  if type(ls) ~= "table" then return false end
  if ls[1] == key then return true end
  for _, v in pairs(ls) do if mentions(v, key) then return true end end
  return false
end

local function open(entity)
  local p = assert(game.players[1])
  remote.call("tt-city", "open_gui", p.index, entity)
  return p, assert(p.gui.screen["tt_city_frame"], "window not open")["body"]
end

--- All captions in a GUI subtree.
local function captions(el, out)
  out = out or {}
  if el.caption then out[#out + 1] = el.caption end
  for _, c in pairs(el.children) do captions(c, out) end
  return out
end

local function any_caption(el, key)
  for _, c in ipairs(captions(el)) do if mentions(c, key) then return true end end
  return false
end

return {
  {
    name = "ui 2.2: the green science city window lists iron plates and circuits as inputs",
    fn = function()
      h.clear_area({ { X - 12, -12 }, { X + 12, 12 } })
      local city = h.place_city("tt-city-green-science", { X + 0.5, 0.5 })
      local p, body = open(city)
      local sprites = {}
      for _, flow in pairs(body.children) do
        for _, c in pairs(flow.children) do if c.type == "sprite" then sprites[c.sprite] = true end end
      end
      assert_.truthy(sprites["item/iron-plate"], "no iron plate line")
      assert_.truthy(sprites["item/electronic-circuit"], "no circuit line")
      assert_.truthy(sprites["item/logistic-science-pack"], "no product line")
      assert_.truthy(any_caption(body, "tt-gui.tier-line"), "no tier line")
      p.opened = nil
    end,
  },
  {
    name = "ui 2.2: the research complex window names the research and the missing packs",
    fn = function(ctx)
      local force = game.forces["player"]
      h.clear_area({ { X + 28, -12 }, { X + 62, 14 } })
      local city = h.place_city("tt-city-research", { X + 40.5, 0.5 })
      h.test_power({ X + 48.5, 0.5 }, 3e6)
      force.cancel_current_research()
      local tech
      for name, t in pairs(force.technologies) do
        if not t.researched and t.enabled and not t.prototype.research_trigger then
          local ok = #t.research_unit_ingredients == 1 and t.research_unit_ingredients[1].name == "automation-science-pack"
          for _, pre in pairs(t.prerequisites) do ok = ok and pre.researched end
          if ok then tech = name; break end
        end
      end
      assert(tech, "no red-only tech")
      force.add_research(tech)
      ctx:wait(10, function()
        local p, body = open(city)
        assert_.equals(body["status"].caption[1], "tt-gui.lab-status-missing")
        assert_.truthy(body["research"], "no research line")
        assert_.truthy(any_caption(body, "tt-gui.lab-speed"), "no speed line")
        p.opened = nil
        force.cancel_current_research()
      end)
    end,
  },
  {
    name = "ui 2.2: upgrading the research complex says how many labs it now equals",
    fn = function()
      h.clear_area({ { X + 68, -12 }, { X + 92, 12 } })
      local city = h.place_city("tt-city-research", { X + 80.5, 0.5 })
      local since = game.tick
      local t2 = assert(remote.call("tt-city", "upgrade_now", city))
      local found = false
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if m.tick >= since and mentions(m.message, "tt-notify.labs") then found = true end
      end
      assert_.truthy(found, "upgrade message does not mention the research speed")
      assert_.equals(t2.name, "tt-city-research-t2")
    end,
  },
  {
    -- playtest 2.2.8: "like 40 labsDraws up to 2.4 MW" ran two sentences together
    name = "ui 2.2: the research complex tier line reads as separate sentences",
    fn = function(ctx)
      h.clear_area({ { X + 98, -12 }, { X + 122, 12 } })
      local city = h.place_city("tt-city-research-t2", { X + 110.5, 0.5 })
      local p, body = open(city)
      local id = p.request_translation(assert(body["tier"], "no tier line").caption)
      p.opened = nil
      ctx:wait_until(function() return h.translations[id] ~= nil end, 300, function()
        local text = h.translations[id].result
        assert_.truthy(text:find("labs. Draws", 1, true), "tier line: " .. text)
      end)
    end,
  },
}
