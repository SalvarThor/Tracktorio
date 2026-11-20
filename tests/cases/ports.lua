-- 2.1.2: construction ports.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local IRON = "tt-city-iron-smelting"

local function status(city) return remote.call("tt-city", "upgrade_status", city) end

local port_of = h.port_of
local feed = h.feed_port

return {
  {
    name = "ports: a tiered city gets a protected port chest inside the building, behind its construction port",
    fn = function()
      h.clear_area({ { 3490, -10 }, { 3512, 10 } })
      local city = h.place_city(IRON, { 3500.5, 0.5 })
      local port = assert(port_of(city), "no port")
      local want = assert(h.box_spot(city, "construction"))
      assert_.equals(port.position.x, want.x, "port x")
      assert_.equals(port.position.y, want.y, "port y")
      local box = city.bounding_box
      assert_.truthy(port.position.x > box.left_top.x and port.position.x < box.right_bottom.x
        and port.position.y > box.left_top.y and port.position.y < box.right_bottom.y, "port chest not inside the building")
      assert_.falsy(port.operable, "port operable")
      assert_.falsy(port.minable_flag, "port minable")
      assert_.falsy(port.destructible, "port destructible")
    end,
  },
  {
    name = "ports: the goal box and a max-tier city have no port",
    fn = function()
      h.clear_area({ { 3520, -10 }, { 3560, 10 } })
      local goal = h.place_city("tt-city-goal", { 3530.5, 0.5 })
      local t3 = h.place_city("tt-city-depot-t3", { 3550.5, 0.5 })
      assert_.falsy(port_of(goal), "goal box has a port")
      assert_.falsy(port_of(t3), "tier 3 has a port")
      assert_.equals(#h.surface().find_entities_filtered({ name = "tt-construction-port", area = { { 3520, -10 }, { 3560, 10 } } }), 0)
    end,
  },
  {
    name = "ports: the iron city's port takes copper plates only",
    fn = function()
      h.clear_area({ { 3570, -10 }, { 3592, 10 } })
      local city = h.place_city(IRON, { 3580.5, 0.5 })
      local inv = assert(assert(port_of(city)).get_inventory(defines.inventory.chest))
      assert_.truthy(inv.can_insert({ name = "copper-plate", count = 1 }), "copper refused")
      for _, other in ipairs({ "iron-plate", "coal", "iron-ore" }) do
        assert_.falsy(inv.can_insert({ name = other, count = 1 }), other .. " accepted")
      end
    end,
  },
  {
    name = "ports: belt deliveries to the construction port are counted and the port is emptied",
    fn = function(ctx)
      h.clear_area({ { 3596, -14 }, { 3626, 16 } })
      local city = h.place_city(IRON, { 3610.5, 0.5 })
      local port = assert(port_of(city))
      -- a belt into the construction port in the wall (2.10.6), 20 plates on it
      local spot = h.port_spots(city, "construction", "input")[1]
      local d = ({ [defines.direction.west] = { -1, 0 }, [defines.direction.east] = { 1, 0 },
        [defines.direction.north] = { 0, -1 }, [defines.direction.south] = { 0, 1 } })[spot.dir]
      local back = ({ [defines.direction.west] = defines.direction.east, [defines.direction.east] = defines.direction.west,
        [defines.direction.north] = defines.direction.south, [defines.direction.south] = defines.direction.north })[spot.dir]
      local chest = h.create("iron-chest", { spot.pos[1] + 2 * d[1], spot.pos[2] + 2 * d[2] })
      chest.insert({ name = "copper-plate", count = 20 })
      h.create("tt-belt-port", { spot.pos[1] + d[1], spot.pos[2] + d[2] }, { direction = back, type = "output" })
      h.create("transport-belt", spot.pos, { direction = back })
      ctx:wait_until(function() return status(city).delivered["copper-plate"] >= 20 end, 60 * 60, function()
        assert_.equals(port.get_inventory(defines.inventory.chest).get_item_count(), 0, "port not emptied")
        assert_.falsy(status(city).complete, "complete after 20 of 2000")
      end)
    end,
  },
  {
    name = "ports: a complete port triggers the upgrade and stops taking that tier's material",
    fn = function()
      h.clear_area({ { 3630, -10 }, { 3652, 10 } })
      local city = h.place_city("tt-city-copper-smelting", { 3640.5, 0.5 })
      local pos = city.position
      local port = assert(port_of(city))
      assert_.equals(status(city).cost["iron-plate"], 2000)
      assert_.equals(feed(city, "iron-plate", 2000), 0, "port refused part of the cost")
      assert_.falsy(port.valid, "old port still there")
      local now = assert(h.city_at(pos), "no city at the old position")
      assert_.equals(now.name, "tt-city-copper-smelting-t2")
      assert_.equals(status(now).cost["iron-plate"], 3000, "tier 3 cost")
      assert_.equals(status(now).cost["electronic-circuit"], 1000, "tier 3 circuits")
      assert_.equals(status(now).delivered["iron-plate"], 0, "tier 3 progress not fresh")
    end,
  },  {
    name = "ports: destroying a city removes its port",
    fn = function(ctx)
      h.clear_area({ { 3660, -10 }, { 3682, 10 } })
      local city = h.place_city(IRON, { 3670.5, 0.5 })
      local port = assert(port_of(city))
      city.destroy()
      ctx:wait(2, function() assert_.falsy(port.valid, "port left behind") end)
    end,
  },
}
