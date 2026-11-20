-- 2.3.3: depot service port and servicing.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local E = defines.direction.east
local X = 7400
local DEPOT = "tt-city-depot"

local function status(city) return remote.call("tt-city", "service_status", city) end

--- Rails along y from X to X+len, a depot south of them at X+60, a train stop (east-bound,
--- south side) at stop_x, and a fuelled locomotive sent there to wait.
local function layout(y, stop_x, len, depot)
  h.clear_area({ { X - 4, y - 6 }, { X + len + 4, y + 20 } })
  for x = X, X + len, 2 do h.create("straight-rail", { x, y }, { direction = E }) end
  local city = h.place_city(depot or DEPOT, { X + 60.5, y + 10.5 })
  local st = h.create("train-stop", { stop_x, y + 2 }, { direction = E })
  st.backer_name = "tt-service-" .. y
  local loco = h.create("locomotive", { X + 6, y }, { direction = E, raise_built = true })
  assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 20 })
  local schedule = assert(loco.train).get_schedule()
  schedule.add_record({ station = st.backer_name, wait_conditions = { { type = "time", compare_type = "and", ticks = 60 * 600 } } })
  schedule.go_to_station(1)
  return city, loco
end

local function arrived(loco)
  return function() return loco.valid and loco.train and loco.train.state == defines.train_state.wait_station end
end

return {
  {
    name = "service: a depot gets a protected service port east of its top-right corner, repair packs only",
    fn = function()
      h.clear_area({ { X - 10, -230 }, { X + 20, -210 } })
      local city = h.place_city(DEPOT, { X + 0.5, -219.5 })
      local s = assert(status(city), "no service status")
      local port = assert(s.port, "no service port")
      local box = city.bounding_box
      assert_.equals(port.position.x, math.ceil(box.right_bottom.x) + 0.5)
      assert_.equals(port.position.y, math.floor(box.left_top.y) + 0.5)
      assert_.falsy(port.operable or port.destructible or port.minable_flag, "port not protected")
      assert_.equals(port.insert({ name = "iron-plate", count = 10 }), 0, "took iron plates")
      assert_.equals(port.insert({ name = "repair-pack", count = 10 }), 10, "refused repair packs")
      assert_.truthy(remote.call("tt-city", "has_window", port), "service port has no window")
      -- the depot's window (also opened by clicking the port) shows the packs
      local p = assert(game.players[1])
      for _, target in ipairs({ city, port }) do
        remote.call("tt-city", "open_gui", p.index, target)
        local line = assert(p.gui.screen["tt_city_frame"])["body"]["service"]
        assert_.truthy(line, "no service line")
        assert_.equals(line.caption[1], "tt-gui.service-packs")
        assert_.equals(line.caption[3], "10")
      end
      p.opened = nil
    end,
  },
  {
    name = "service: only depots have a service port",
    fn = function()
      h.clear_area({ { X + 20, -230 }, { X + 40, -210 } })
      local city = h.place_city("tt-city-iron-smelting", { X + 30.5, -219.5 })
      assert_.equals(status(city), nil)
    end,
  },
  {
    name = "service: the packs stay through a depot upgrade; destroying the depot removes its port",
    fn = function(ctx)
      h.clear_area({ { X + 50, -230 }, { X + 70, -210 } })
      local city = h.place_city(DEPOT, { X + 60.5, -219.5 })
      local port = assert(status(city).port)
      port.insert({ name = "repair-pack", count = 7 })
      local t2 = assert(remote.call("tt-city", "upgrade_now", city))
      local s = assert(status(t2), "tier 2 depot has no service status")
      assert_.equals(s.packs, 7)
      -- 2.10: the bigger building moves the port; the old one must not be left behind
      assert_.truthy(s.port == port or not port.valid, "old service port left under the building")
      local new_port = assert(s.port)
      t2.destroy({ raise_destroy = true })
      ctx:wait(2, function() -- on_object_destroyed arrives a tick later
        assert_.falsy(new_port.valid, "service port left behind")
      end)
    end,
  },
  {
    name = "service: a train stopped near a depot is repaired with packs, cured at full health",
    fn = function(ctx)
      local city, loco = layout(300, X + 80, 120)
      ctx:wait_until(arrived(loco), 1200, function()
        remote.call("tt-reliability", "set", loco, 0.25)
        remote.call("tt-reliability", "break_down", loco)
        local start = loco.health
        -- no packs: nothing happens
        ctx:wait(120, function()
          assert_.equals(loco.health, start, "repaired without packs")
          assert(status(city).port).insert({ name = "repair-pack", count = 10 })
          ctx:wait_until(function() return loco.health >= loco.max_health end, 900, function()
            local s = assert(status(city))
            local used = 10 - s.packs
            local expected = math.ceil((loco.max_health - start) / 300)
            assert_.equals(used, expected, "packs used")
            assert_.equals(s.serviced, 1)
            ctx:wait(70, function()
              assert_.falsy(remote.call("tt-reliability", "is_broken", loco), "still broken at full health")
            end)
          end)
        end)
      end)
    end,
  },
  {
    name = "service: repair runs at 100 health per second",
    fn = function(ctx)
      local city, loco = layout(340, X + 80, 120)
      ctx:wait_until(arrived(loco), 1200, function()
        assert(status(city).port).insert({ name = "repair-pack", count = 10 })
        remote.call("tt-reliability", "set", loco, 0.25)
        local start = loco.health
        ctx:wait(180, function()
          local gained = loco.health - start
          assert_.truthy(gained >= 200 and gained <= 300, "gained " .. gained .. " in 3 s")
        end)
      end)
    end,
  },
  {
    name = "service: a train stop out of range does nothing",
    fn = function(ctx)
      local city, loco = layout(380, X + 140, 180)
      ctx:wait_until(arrived(loco), 1200, function()
        assert(status(city).port).insert({ name = "repair-pack", count = 10 })
        remote.call("tt-reliability", "set", loco, 0.25)
        local start = loco.health
        ctx:wait(120, function()
          assert_.equals(loco.health, start, "repaired out of range")
          assert_.equals(status(city).packs, 10)
        end)
      end)
    end,
  },
  {
    name = "service: an older depot gets its service port on migration; a blocked tile is reported once",
    fn = function()
      h.clear_area({ { X + 80, -230 }, { X + 100, -210 } })
      local city = h.place_city(DEPOT, { X + 90.5, -219.5 })
      remote.call("tt-city", "strip_to_mvp", city)
      assert_.equals(status(city), nil)
      local box = city.bounding_box
      local tile = { math.ceil(box.right_bottom.x) + 0.5, math.floor(box.left_top.y) + 0.5 }
      local blocker = h.create("iron-chest", tile)
      local t0 = game.tick
      remote.call("tt-city", "migrate", 1)
      remote.call("tt-city", "service_tick"); remote.call("tt-city", "service_tick")
      assert_.truthy(blocker.valid, "the player's chest was removed")
      local s = status(city)
      assert_.truthy(s and not s.port, "service port placed over the player's chest")
      local n = 0
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if m.tick >= t0 and m.message[1] == "tt-notify.service-port-blocked" then n = n + 1 end
      end
      assert_.equals(n, 1, "blocked message count")
      blocker.destroy()
      remote.call("tt-city", "service_tick")
      assert_.truthy(assert(status(city)).port, "service port did not appear after clearing the tile")
    end,
  },
  {
    name = "service: the generated map's depot has its service port and the repair pack city is placed",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-service")
      local depot = surface.find_entities_filtered({ name = DEPOT })[1]
      assert(depot, "no depot on the map")
      assert_.truthy(assert(status(depot)).port, "map depot has no service port")
      assert_.equals(surface.count_entities_filtered({ name = "tt-city-repair-packs" }), 1)
    end,
  },
  {
    -- playtest 2.4.6 step 8 was not actually tried in game; cover it here
    name = "service: the solid and rocket fuel depots service stopped trains too",
    fn = function(ctx)
      local depots = { "tt-city-solid-fuel-depot", "tt-city-rocket-fuel-depot" }
      local runs = {}
      for i, name in ipairs(depots) do
        local city, loco = layout(460 + i * 40, X + 80, 120, name)
        runs[i] = { city = city, loco = loco }
      end
      ctx:wait_until(function()
        for _, r in ipairs(runs) do if not arrived(r.loco)() then return false end end
        return true
      end, 1200, function()
        for _, r in ipairs(runs) do
          assert(assert(status(r.city)).port).insert({ name = "repair-pack", count = 10 })
          remote.call("tt-reliability", "set", r.loco, 0.25)
          r.start = r.loco.health
        end
        ctx:wait(130, function()
          for i, r in ipairs(runs) do
            assert_.truthy(r.loco.health > r.start + 100, depots[i] .. " did not repair: " .. (r.loco.health - r.start))
          end
        end)
      end)
    end,
  },
  {
    -- playtest 2.3.5: stopping by hand at the stop never serviced the train
    name = "service: a manually driven train standing at a stop near a depot is repaired",
    fn = function(ctx)
      local y = 420
      h.clear_area({ { X - 4, y - 6 }, { X + 124, y + 20 } })
      for x = X, X + 120, 2 do h.create("straight-rail", { x, y }, { direction = E }) end
      local city = h.place_city(DEPOT, { X + 60.5, y + 10.5 })
      local st = h.create("train-stop", { X + 80, y + 2 }, { direction = E })
      st.backer_name = "tt-service-manual"
      local loco = h.create("locomotive", { X + 77, y }, { direction = E, raise_built = true })
      assert(loco.get_fuel_inventory()).insert({ name = "tt-coal-fuel", count = 5 })
      assert(loco.train).manual_mode = true
      assert(assert(status(city)).port).insert({ name = "repair-pack", count = 10 })
      remote.call("tt-reliability", "set", loco, 0.25)
      local start = loco.health
      ctx:wait(130, function()
        assert_.truthy(loco.health > start + 100, "not repaired: " .. (loco.health - start))
      end)
    end,
  },
}