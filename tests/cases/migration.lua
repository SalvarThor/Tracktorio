-- 2.1.5: MVP (schema 1) saves gain ports and upgrades; blocked port tiles are handled.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local function messages_since(tick)
  local out = {}
  for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
    if m.tick >= tick and type(m.message) == "table" and m.message[1] == "tt-notify.port-blocked" then out[#out + 1] = m end
  end
  return out
end

return {
  {
    name = "migration: an MVP-era city gets its port and can then upgrade",
    fn = function()
      h.clear_area({ { 4200, -12 }, { 4222, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { 4210.5, 0.5 })
      local pos = city.position
      remote.call("tt-city", "strip_to_mvp", city)
      assert_.falsy(h.port_of(city), "still has a port after stripping")
      remote.call("tt-city", "migrate", 1)
      local port = assert(h.port_of(city), "migration did not add a port")
      assert_.equals(port.position.x, 4205.5); assert_.equals(port.position.y, -3.5)
      assert_.equals(remote.call("tt-city", "upgrade_status", city).delivered["copper-plate"], 0)
      assert_.equals(h.feed_port(city, "copper-plate", 2000), 0)
      assert_.equals(assert(h.city_at(pos)).name, "tt-city-iron-smelting-t2")
    end,
  },
  {
    name = "migration: a blocked port tile is reported once and the port appears when cleared",
    fn = function()
      h.clear_area({ { 4240, -12 }, { 4262, 12 } })
      local city = h.place_city("tt-city-copper-smelting", { 4250.5, 0.5 })
      remote.call("tt-city", "strip_to_mvp", city)
      local blocker = h.create("iron-chest", { 4245.5, -3.5 }) -- the player's chest on the port tile
      local t0 = game.tick
      remote.call("tt-city", "migrate", 1)
      assert_.falsy(h.port_of(city), "port placed over the player's chest")
      assert_.truthy(blocker.valid, "the player's chest was removed")
      remote.call("tt-city", "port_tick"); remote.call("tt-city", "port_tick")
      assert_.equals(#messages_since(t0), 1, "blocked message count")
      blocker.destroy()
      remote.call("tt-city", "port_tick")
      assert_.truthy(h.port_of(city), "port did not appear after clearing the tile")
    end,
  },
  {
    name = "migration: running it twice changes nothing (idempotent)",
    fn = function()
      h.clear_area({ { 4280, -12 }, { 4302, 12 } })
      local city = h.place_city("tt-city-depot", { 4290.5, 0.5 })
      local port = assert(h.port_of(city))
      h.feed_port(city, "iron-plate", 100)
      remote.call("tt-city", "migrate", 1)
      remote.call("tt-city", "migrate")
      assert_.truthy(port.valid, "migration replaced an existing port")
      assert_.equals(remote.call("tt-city", "upgrade_status", city).delivered["iron-plate"], 100, "progress lost")
      assert_.equals(#h.surface().find_entities_filtered({ name = "tt-construction-port", area = { { 4280, -12 }, { 4302, 12 } } }), 1)
    end,
  },
  {
    name = "migration: every upgradable city on the generated map has its port",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-ports")
      for _, c in ipairs(remote.call("tt-map", "layout").cities) do
        local city = surface.find_entities_filtered({ name = c.name, position = { c.x + 0.5, c.y + 0.5 }, radius = 1 })[1]
        assert(city, "missing " .. c.name)
        if c.name ~= "tt-city-goal" then
          assert_.truthy(h.port_of(city), c.name .. " has no port on the map")
        end
      end
    end,
  },
  {
    name = "migration: a pending upgrade picks up changed costs and keeps its deliveries",
    fn = function()
      local x = 5400
      h.clear_area({ { x - 12, -12 }, { x + 12, 12 } })
      local city = h.place_city("tt-city-iron-smelting-t2", { x + 0.5, 0.5 })
      remote.call("tt-city", "set_upgrade_cost", city, { ["copper-plate"] = 6000 }, { ["copper-plate"] = 4000 })
      remote.call("tt-city", "migrate")
      local s = assert(remote.call("tt-city", "upgrade_status", city))
      assert_.equals(s.cost["copper-plate"], 3000)
      assert_.equals(s.cost["electronic-circuit"], 1000)
      assert_.equals(s.delivered["copper-plate"], 4000)
      assert_.equals(s.delivered["electronic-circuit"], 0)
    end,
  },
}
