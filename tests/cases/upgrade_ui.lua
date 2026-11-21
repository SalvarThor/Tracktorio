-- 2.1.4: tier UI, port window, map tags and upgrade notifications.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

--- Does a localised string (nested tables) contain this key anywhere?
local function mentions(ls, key)
  if type(ls) ~= "table" then return false end
  if ls[1] == key then return true end
  for _, v in pairs(ls) do if mentions(v, key) then return true end end
  return false
end

local function messages_since(tick)
  local out = {}
  for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
    if m.tick >= tick then out[#out + 1] = m.message end
  end
  return out
end

local function any_mentions(list, key)
  for _, m in ipairs(list) do if mentions(m, key) then return true end end
  return false
end

local function open(entity)
  local p = assert(game.players[1])
  remote.call("tt-city", "open_gui", p.index, entity)
  return p, assert(p.gui.screen["tt_city_frame"], "window not open")["body"]
end

return {
  {
    name = "upgrade ui: a city window shows its tier and the next tier's materials",
    fn = function()
      h.clear_area({ { 4000, -12 }, { 4022, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { 4010.5, 0.5 })
      local p, body = open(city)
      local tier = assert(body["tier"], "no tier line")
      assert_.equals(tier.caption[1], "tt-gui.tier-line")
      -- 2.13: each material is one row (icon, count, bar)
      local bars = 0
      for _, c in ipairs(body.children) do
        if c.name:find("^material%-") then
          for _, x in ipairs(c.children) do if x.type == "progressbar" then bars = bars + 1 end end
        end
      end
      assert_.equals(bars, 1, "material progress bars")
      p.opened = nil
    end,
  },
  {
    name = "upgrade ui: clicking the construction port opens a window for its city",
    fn = function()
      h.clear_area({ { 4030, -12 }, { 4052, 12 } })
      local city = h.place_city("tt-city-depot", { 4040.5, 0.5 })
      local port = assert(h.port_of(city))
      assert_.truthy(remote.call("tt-city", "has_window", port), "port has no window")
      local p, body = open(port)
      assert_.equals(body["status"].caption[1], "tt-gui.port-for")
      assert_.truthy(body["tier"], "port window has no tier section")
      p.opened = nil
    end,
  },
  {
    name = "upgrade ui: a heads-up at 90%, once, then an upgrade message, alert and flying text",
    fn = function()
      h.clear_area({ { 4060, -12 }, { 4082, 12 } })
      local city = h.place_city("tt-city-copper-smelting", { 4070.5, 0.5 })
      local pos = city.position
      local t0 = game.tick
      h.feed_port(city, "iron-plate", 1800)
      assert_.truthy(any_mentions(messages_since(t0), "tt-notify.heads-up"), "no heads-up at 90%")
      h.feed_port(city, "iron-plate", 100)
      local heads_ups = 0
      for _, m in ipairs(messages_since(t0)) do if mentions(m, "tt-notify.heads-up") then heads_ups = heads_ups + 1 end end
      assert_.equals(heads_ups, 1, "heads-up count")
      h.feed_port(city, "iron-plate", 100)
      local msgs = messages_since(t0)
      assert_.truthy(any_mentions(msgs, "tt-notify.upgraded"), "no upgrade message")
      assert_.truthy(any_mentions(msgs, "tt-notify.no-coal"), "message doesn't say it stopped using coal")
      assert_.truthy(any_mentions(msgs, "tt-notify.not-connected"), "no warning for an unpowered electric city")
      local now = assert(h.city_at(pos))
      local p = assert(game.players[1])
      local alerts = p.get_alerts({ entity = now, type = defines.alert_type.custom })
      local count = 0
      for _, per_surface in pairs(alerts) do for _, list in pairs(per_surface) do count = count + #list end end
      assert_.truthy(count >= 1, "no custom alert")
    end,
  },
  {
    name = "upgrade ui: a weak network is called out when the city upgrades",
    fn = function()
      local city = h.city_rig("tt-city-iron-smelting", 4100, {}, false)
      local pos = city.position
      h.test_power({ 4107, 0 }, 1e6) -- a network with no power city on it
      local t0 = game.tick
      h.feed_port(city, "copper-plate", 2000)
      assert_.truthy(h.city_at(pos).name == "tt-city-iron-smelting-t2", "did not upgrade")
      assert_.truthy(any_mentions(messages_since(t0), "tt-notify.no-power-city"), "no no-power-city warning")
    end,
  },
  {
    -- playtest 2.10: a power city on the same poles counts (its hidden generator is on the network)
    name = "upgrade ui: with a power city on its poles, the network check counts its output",
    fn = function(ctx)
      h.clear_area({ { 4140, -14 }, { 4200, 16 } })
      local depot = h.place_city("tt-city-depot", { 4150.5, 0.5 })
      local power = h.place_city("tt-city-power", { 4180.5, 0.5 })
      for x = 4156.5, 4174.5, 6 do h.create("medium-electric-pole", { x, 0.5 }) end
      ctx:wait(2, function()
        local w = remote.call("tt-city", "network_warning", depot)
        assert_.falsy(w, "warning with a 5.4 MW power city for a 0.84 MW depot: " .. serpent.line(w))
        assert_.truthy(power.valid)
      end)
    end,
  },
  {
    name = "upgrade ui: custom alerts clear after 30 s",
    fn = function(ctx)
      assert_.truthy(remote.call("tt-city", "alerts_pending") > 0, "no alerts pending from earlier upgrades")
      ctx:wait(60 * 31, function()
        assert_.equals(remote.call("tt-city", "alerts_pending"), 0, "alerts not cleared")
      end)
    end,
  },
  {
    name = "upgrade ui: the map tag shows the new tier",
    fn = function(ctx)
      local surface = remote.call("tt-map", "generate", "tt-map-upgrade-ui") -- own surface: map.lua checks tt-map-test
      local force = game.forces["player"]
      ctx:wait_until(function()
        remote.call("tt-map", "tick_tags")
        return #force.find_chart_tags(surface) >= 5
      end, 60 * 30, function()
        local city
        for _, e in pairs(surface.find_entities_filtered({ name = "tt-city-depot" })) do city = e end
        assert(city, "no depot on the map surface")
        local now = assert(remote.call("tt-city", "upgrade_now", city), "upgrade_now returned nothing")
        local tags = force.find_chart_tags(surface, { { now.position.x - 1, now.position.y - 1 }, { now.position.x + 1, now.position.y + 1 } })
        assert_.equals(#tags, 1, "tag count at the depot")
        assert_.equals(assert(tags[1]).text, "Coal fuel depot (tier 2)")
      end)
    end,
  },
  {
    -- playtest 2.6.6: 0.6 and 1.2 fuel cells/min both read "1"
    name = "upgrade ui: slow rates keep a decimal in the tier lines (uranium city 0.6 then 1.2/min)",
    fn = function()
      h.clear_area({ { 4400, 40 }, { 4422, 64 } })
      local city = h.place_city("tt-city-uranium", { 4410.5, 50.5 })
      local p, body = open(city)
      local function rate_of(caption)
        if type(caption) ~= "table" then return nil end
        if caption[1] == "tt-notify.rate" then return caption[2] end
        for i = 2, #caption do
          local r = rate_of(caption[i])
          if r then return r end
        end
      end
      assert_.equals(rate_of(body["tier"].caption), "0.6")
      local next_line
      for _, c in ipairs(body.children) do
        if c.type == "label" and type(c.caption) == "table" and c.caption[1] == "tt-gui.tier-next" then next_line = c end
      end
      assert_.equals(rate_of(assert(next_line, "no next tier line").caption), "1.2")
      p.opened = nil
    end,
  },
}
