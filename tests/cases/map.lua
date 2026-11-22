-- 1.8: scripted MVP map (built on a scratch surface with the same generator).
local assert_ = require("__tracktorio-tests__/assert")

local SURFACE = "tt-map-test"

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function layout() return remote.call("tt-map", "layout") end

local function city_pos(name)
  for _, c in ipairs(layout().cities) do if c.name == name then return c end end
  error("no city " .. name)
end

return {
  {
    name = "map: generates the surface with every city in place",
    fn = function()
      local surface = remote.call("tt-map", "generate", SURFACE)
      assert_.truthy(surface and surface.valid, "no surface")
      for _, c in ipairs(layout().cities) do
        local found = surface.find_entities_filtered({ name = c.name, position = { c.x + 0.5, c.y + 0.5 }, radius = 1 })
        assert_.equals(#found, 1, c.name)
        assert_.falsy(found[1].operable, c.name .. " operable")
      end
    end,
  },
  {
    name = "map: ore, coal and water exist with enough resource for the goal",
    fn = function()
      local surface = assert(game.get_surface(SURFACE))
      for _, p in ipairs(layout().patches) do
        local area = { { p.x - p.radius - 1, p.y - p.radius - 1 }, { p.x + p.radius + 1, p.y + p.radius + 1 } }
        local total = 0
        for _, e in pairs(surface.find_entities_filtered({ area = area, name = p.name })) do total = total + e.amount end
        assert_.truthy(total > 200000, p.name .. " total " .. total)
      end
      local lakes = layout().lakes
      assert_.truthy(#lakes >= 2, "expected at least two lakes")
      for _, lake in ipairs(lakes) do
        assert_.equals(surface.get_tile(lake.x, lake.y).name, "deepwater")
        assert_.truthy(surface.get_tile(lake.x + lake.radius - 1, lake.y).name == "water", "lake edge")
      end
    end,
  },
  {
    name = "map: patches and water are far from the cities; depot is near the start",
    fn = function()
      local l = layout()
      for _, p in ipairs(l.patches) do
        for _, c in ipairs(l.cities) do
          assert_.truthy(dist(p, c) >= 100, p.name .. " too close to " .. c.name .. ": " .. dist(p, c))
        end
      end
      for _, lake in ipairs(l.lakes) do
        for _, c in ipairs(l.cities) do
          assert_.truthy(dist(lake, c) >= 100, "lake too close to " .. c.label)
        end
      end
      -- cities don't crowd each other (9x9 plus ports)
      for i, a in ipairs(l.cities) do
        for j = i + 1, #l.cities do
          assert_.truthy(dist(a, l.cities[j]) >= 40, a.label .. " too close to " .. l.cities[j].label)
        end
        assert_.truthy(math.abs(a.x) <= l.width / 2 - 16 and math.abs(a.y) <= l.height / 2 - 16, a.label .. " at the map edge")
      end
      assert_.truthy(dist(city_pos("tt-city-depot"), l.spawn) <= 40, "depot not near spawn")
    end,
  },
  {
    name = "map: every city gets a labelled map tag",
    fn = function(ctx)
      local surface = assert(game.get_surface(SURFACE))
      local force = game.forces["player"]
      ctx:wait_until(function()
        remote.call("tt-map", "tick_tags")
        return #force.find_chart_tags(surface) >= #layout().cities
      end, 60 * 30, function()
        local labels = {}
        for _, t in ipairs(force.find_chart_tags(surface)) do labels[t.text] = true end
        for _, c in ipairs(layout().cities) do
          assert_.truthy(labels[c.label], "no tag " .. c.label)
        end
      end)
    end,
  },
  {
    name = "map: generation is reproducible",
    fn = function()
      local a = assert(game.get_surface(SURFACE))
      local b = remote.call("tt-map", "generate", SURFACE .. "-2")
      for _, p in ipairs(layout().patches) do
        local function sum(s)
          local t = 0
          for _, e in pairs(s.find_entities_filtered({ name = p.name })) do t = t + e.amount end
          return t
        end
        assert_.equals(sum(b), sum(a), p.name .. " differs")
      end
      assert_.equals(#b.find_entities_filtered({ type = "tree" }), 0, "trees generated")
      assert_.equals(#b.find_entities_filtered({ type = "cliff" }), 0, "cliffs generated")
      assert_.equals(#b.find_entities_filtered({ force = "enemy" }), 0, "enemies generated")
    end,
  },
  {
    name = "map: a new player spawns on the map with starting coal fuel",
    fn = function()
      local p = assert(game.players[1])
      p.get_main_inventory().clear()
      remote.call("tt-map", "setup_player", p.index)
      assert_.equals(p.surface.name, "tracktorio")
      assert_.equals(p.get_item_count("tt-coal-fuel"), 20)
      -- move back so later tests keep using surface 1
      p.teleport({ 0, 0 }, game.surfaces[1])
    end,
  },
  {
    name = "map: a 2.1-size map is extended in place with the new cities; a blocked spot waits",
    fn = function()
      local name = "tt-map-legacy"
      local surface = remote.call("tt-map", "generate", name)
      local l = layout()
      local OLD_W, OLD_H = 640, 400
      -- Turn it into a 2.1 map: only the MVP cities, no second iron patch, 640 x 400.
      local new_cities = {}
      for _, c in ipairs(l.cities) do
        if math.abs(c.x) > 300 or math.abs(c.y) > 180 then
          new_cities[#new_cities + 1] = c
          for _, e in pairs(surface.find_entities_filtered({ position = { c.x + 0.5, c.y + 0.5 }, radius = 1 })) do e.destroy() end
        end
      end
      assert_.truthy(#new_cities >= 4, "expected the new cities outside the old bounds")
      local east_iron
      for _, p in ipairs(l.patches) do if p.name == "iron-ore" and p.x > 300 then east_iron = p end end
      assert(east_iron, "no second iron patch in the layout")
      for _, e in pairs(surface.find_entities_filtered({ name = "iron-ore", position = { east_iron.x, east_iron.y }, radius = east_iron.radius + 1 })) do
        e.destroy()
      end
      local tiles = {}
      for x = -l.width / 2, l.width / 2 - 1 do
        for y = -l.height / 2, l.height / 2 - 1 do
          if x < -OLD_W / 2 or x >= OLD_W / 2 or y < -OLD_H / 2 or y >= OLD_H / 2 then
            tiles[#tiles + 1] = { name = "out-of-map", position = { x, y } }
          end
        end
      end
      surface.set_tiles(tiles)
      local mgs = surface.map_gen_settings
      mgs.width, mgs.height = OLD_W, OLD_H
      surface.map_gen_settings = mgs
      -- Ports of the destroyed cities go one tick later; remove them now.
      for _, e in pairs(surface.find_entities_filtered({ name = { "tt-belt-port", "tt-belt-port-service", "tt-service-port", "tt-signal-point", "tt-throttle-beacon", "tt-hidden-radar" } })) do
        local near = false
        for _, c in ipairs(new_cities) do if math.abs(e.position.x - c.x) < 8 and math.abs(e.position.y - c.y) < 8 then near = true end end
        if near then e.destroy() end
      end
      -- The player built something where the green science city goes.
      local green
      for _, c in ipairs(new_cities) do if c.name == "tt-city-green-science" then green = c end end
      assert(green, "no green science city in the layout")
      surface.set_tiles({ { name = "grass-1", position = { green.x, green.y } } })
      local chest = assert(surface.create_entity({ name = "iron-chest", position = { green.x + 0.5, green.y + 0.5 }, force = "player" }))

      remote.call("tt-map", "extend", name)

      assert_.equals(surface.map_gen_settings.width, l.width)
      assert_.equals(surface.count_tiles_filtered({ name = "out-of-map",
        area = { { -l.width / 2, -l.height / 2 }, { l.width / 2, l.height / 2 } } }), 0, "out-of-map tiles left")
      assert_.truthy(surface.count_entities_filtered({ name = "iron-ore", position = { east_iron.x, east_iron.y }, radius = 2 }) > 0,
        "second iron patch missing")
      for _, c in ipairs(new_cities) do
        local n = surface.count_entities_filtered({ name = c.name, position = { c.x + 0.5, c.y + 0.5 }, radius = 1 })
        assert_.equals(n, c == green and 0 or 1, c.name)
      end
      assert_.truthy(chest.valid, "the player's chest was removed")
      assert_.truthy(remote.call("tt-map", "blocked")[name .. "/" .. green.name .. "@" .. green.x .. "," .. green.y], "blocked spot not recorded")
      local west_lake
      for _, lake in ipairs(l.lakes) do if lake.x < -320 then west_lake = lake end end
      assert(west_lake, "no lake outside the old bounds")
      assert_.equals(surface.get_tile(west_lake.x, west_lake.y).name, "deepwater", "new lake not placed")
      local said = false
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if type(m.message) == "table" and m.message[1] == "tt-notify.city-blocked" then said = true end
      end
      assert_.truthy(said, "no blocked-city message")
      -- Clear the spot: the next retry places it.
      chest.destroy()
      remote.call("tt-map", "retry_blocked")
      assert_.equals(surface.count_entities_filtered({ name = green.name, position = { green.x + 0.5, green.y + 0.5 }, radius = 1 }), 1)
      -- Running it again changes nothing.
      local before = surface.count_entities_filtered({ type = "assembling-machine" })
      remote.call("tt-map", "extend", name)
      assert_.equals(surface.count_entities_filtered({ type = "assembling-machine" }), before)
    end,
  },
  {
    name = "map: four coal power cities, each with its own label",
    fn = function()
      local surface = assert(game.get_surface(SURFACE))
      local labels = {}
      for _, c in ipairs(layout().cities) do
        if c.name == "tt-city-power" then
          assert_.falsy(labels[c.label], "duplicate label " .. c.label)
          labels[c.label] = true
          assert_.equals(surface.count_entities_filtered({ name = c.name, position = { c.x + 0.5, c.y + 0.5 }, radius = 1 }), 1, c.label)
        end
      end
      assert_.equals(table_size(labels), 4)
    end,
  },
  {
    name = "map: a lake blocked by the player's building waits, is reported once, then appears",
    fn = function()
      local name = "tt-map-lake"
      local surface = remote.call("tt-map", "generate", name)
      local lake = layout().lakes[2]
      local tiles = {}
      for x = lake.x - lake.radius - 1, lake.x + lake.radius + 1 do
        for y = lake.y - lake.radius - 1, lake.y + lake.radius + 1 do tiles[#tiles + 1] = { name = "grass-1", position = { x, y } } end
      end
      surface.set_tiles(tiles)
      local chest = assert(surface.create_entity({ name = "iron-chest", position = { lake.x + 3.5, lake.y + 0.5 }, force = "player" }))
      remote.call("tt-map", "extend", name)
      local key = name .. "/lake@" .. lake.x .. "," .. lake.y
      assert_.truthy(remote.call("tt-map", "blocked")[key], "blocked lake not recorded")
      assert_.equals(surface.get_tile(lake.x, lake.y).name, "grass-1", "lake placed over the chest")
      local said = 0
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if type(m.message) == "table" and m.message[1] == "tt-notify.lake-blocked" then said = said + 1 end
      end
      remote.call("tt-map", "retry_blocked")
      local again = 0
      for _, m in ipairs(remote.call("tt-city", "recent_messages")) do
        if type(m.message) == "table" and m.message[1] == "tt-notify.lake-blocked" then again = again + 1 end
      end
      assert_.equals(said, 1, "lake message count")
      assert_.equals(again, 1, "lake reported twice")
      chest.destroy()
      remote.call("tt-map", "retry_blocked")
      assert_.equals(surface.get_tile(lake.x, lake.y).name, "deepwater", "lake not placed after clearing")
      assert_.falsy(remote.call("tt-map", "blocked")[key], "blocked entry left")
    end,
  },
}
