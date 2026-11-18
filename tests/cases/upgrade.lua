-- 2.1.3: upgrade in place when the construction port is complete.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local function status(city) return remote.call("tt-city", "upgrade_status", city) end

local function listed(entity)
  for _, u in ipairs(remote.call("tt-city", "list", entity.name)) do
    if u == entity.unit_number then return true end
  end
  return false
end

return {
  {
    name = "upgrade: a smelting city goes to tier 2, keeps its ore and plates, spills its coal",
    fn = function()
      h.clear_area({ { 3700, -12 }, { 3722, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { 3710.5, 0.5 })
      local pos = city.position
      city.insert({ name = "iron-ore", count = 30 })
      city.insert({ name = "coal", count = 3 })
      assert(city.get_inventory(defines.inventory.crafter_output)).insert({ name = "iron-plate", count = 40 })
      local in_ore = city.get_inventory(defines.inventory.crafter_input).get_item_count("iron-ore")
      assert_.equals(h.feed_port(city, "copper-plate", 2000), 0, "port refused copper")
      assert_.falsy(city.valid, "old city still there")
      local now = assert(h.city_at(pos))
      assert_.equals(now.name, "tt-city-iron-smelting-t2")
      assert_.equals(now.position.x, pos.x); assert_.equals(now.position.y, pos.y)
      assert_.falsy(now.operable, "new tier not protected")
      assert_.truthy(listed(now), "new tier not tracked")
      assert_.equals(now.get_inventory(defines.inventory.crafter_input).get_item_count("iron-ore"), in_ore, "ore lost")
      assert_.equals(now.get_inventory(defines.inventory.crafter_output).get_item_count("iron-plate"), 40, "plates lost")
      local spilled = 0
      for _, e in pairs(h.surface().find_entities_filtered({ type = "item-entity", area = { { 3700, -12 }, { 3722, 12 } } })) do
        if e.stack.name == "coal" then spilled = spilled + e.stack.count end
      end
      assert_.truthy(spilled > 0, "coal neither kept nor spilled")
      assert_.truthy(h.port_of(now), "tier 2 has no port for tier 3")
    end,
  },
  {
    name = "upgrade: the upgraded electric city runs on power without coal",
    fn = function(ctx)
      local city, _, cout = h.city_rig("tt-city-iron-smelting", 3740, { { name = "iron-ore", count = 100 } }, true)
      local pos = city.position
      h.test_power({ 3747, 0 }, 10e6)
      h.feed_port(city, "copper-plate", 2000)
      local now = assert(h.city_at(pos))
      assert_.equals(now.name, "tt-city-iron-smelting-t2")
      ctx:wait_until(function() return cout.get_item_count("iron-plate") > 0 end, 60 * 30, function()
        assert_.truthy(now.products_finished > 0, "tier 2 made nothing")
      end)
    end,
  },
  {
    name = "upgrade: a power city gets its tier 2 generator, linked, and the old one is gone",
    fn = function()
      h.clear_area({ { 3770, -12 }, { 3796, 14 } })
      local city = h.place_city("tt-city-power", { 3780.5, 0.5 })
      local pos = city.position
      h.feed_port(city, "iron-plate", 1000)
      h.feed_port(city, "copper-plate", 1000)
      local now = assert(h.city_at(pos))
      assert_.equals(now.name, "tt-city-power-t2")
      local area = { { 3775, -5 }, { 3786, 6 } }
      assert_.equals(#h.surface().find_entities_filtered({ name = "tt-power-generator", area = area }), 0, "old generator left")
      assert_.equals(#h.surface().find_entities_filtered({ name = "tt-power-generator-t2", area = area }), 1, "no tier 2 generator")
      local links = now.get_fluid_box_linked_connections()
      assert_.truthy(links and #links >= 1, "tier 2 generator not linked")
    end,
  },
  {
    name = "upgrade: tier 3 is the last; it has no port",
    fn = function()
      h.clear_area({ { 3810, -12 }, { 3832, 12 } })
      local city = h.place_city("tt-city-depot", { 3820.5, 0.5 })
      local pos = city.position
      h.feed_port(city, "iron-plate", 1000); h.feed_port(city, "copper-plate", 1000)
      local t2 = assert(h.city_at(pos))
      h.feed_port(t2, "iron-plate", 3000); h.feed_port(t2, "copper-plate", 3000)
      local t3 = assert(h.city_at(pos))
      assert_.equals(t3.name, "tt-city-depot-t3")
      assert_.falsy(h.port_of(t3), "tier 3 has a port")
      assert_.equals(status(t3).tier, 3)
    end,
  },
  {
    name = "upgrade: an open city window follows the new tier",
    fn = function(ctx)
      h.clear_area({ { 3850, -12 }, { 3872, 12 } })
      local city = h.place_city("tt-city-copper-smelting", { 3860.5, 0.5 })
      local pos = city.position
      local p = assert(game.players[1])
      remote.call("tt-city", "open_gui", p.index, city)
      h.feed_port(city, "iron-plate", 2000)
      local now = assert(h.city_at(pos))
      ctx:wait(61, function()
        local frame = p.gui.screen["tt_city_frame"]
        assert_.truthy(frame and frame.valid, "window closed by the upgrade")
        p.opened = nil
        assert_.truthy(now.valid)
      end)
    end,
  },
  {
    name = "upgrade: backpressure still stalls an upgraded city",
    fn = function(ctx)
      local city = h.city_rig("tt-city-depot", 3900, { { name = "coal", count = 200 } }, false)
      local pos = city.position
      h.test_power({ 3907, 0 }, 5e6)
      h.feed_port(city, "iron-plate", 1000); h.feed_port(city, "copper-plate", 1000)
      local now = assert(h.city_at(pos))
      now.insert({ name = "coal", count = 100 })
      ctx:wait_until(function() return remote.call("tt-city", "info", now).status == "output_full" end, 60 * 120, function()
        local made = now.products_finished
        ctx:wait(60 * 5, function() assert_.equals(now.products_finished, made, "kept crafting while full") end)
      end)
    end,
  },
}
