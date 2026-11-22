-- 2.10: belt ports. A port is a hidden loader at the city wall; these tests pin down what
-- 2.1 loaders do with cities.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local port_layout = require("__tracktorio__/shared/port_layout")
local city_defs = require("__tracktorio__/shared/city_defs")

local X = 40000
local D = defines.direction

--- infinity chest -> loader -> belt -> loader at `pos`, moving items south into what is
--- south of `pos`. Returns the last loader and the belt.
---@param pos number[]
---@param item string
local function feed(pos, item)
  local x, y = pos[1], pos[2]
  local inf = h.create("infinity-chest", { x, y - 3 })
  inf.set_infinity_container_filter(1, { name = item, count = 100, mode = "exactly" })
  h.create("loader-1x1", { x, y - 2 }, { direction = D.south, type = "output" })
  local belt = h.create("transport-belt", { x, y - 1 }, { direction = D.south })
  return h.create("loader-1x1", { x, y }, { direction = D.south, type = "input" }), belt
end

--- A city centred at (x + 0.5, 0.5) in a cleared area; returns it and the y of the tile
--- rows just outside its north and south walls.
---@param name string
---@param x number
local function city_at(name, x)
  local half = h.city_size(name) / 2
  h.clear_area({ { x - half - 6, 0.5 - half - 8 }, { x + half + 6, 0.5 + half + 8 } })
  local city = h.place_city(name, { x + 0.5, 0.5 })
  local e = h.edges(city)
  return city, e.top, e.bottom
end

---@param loader LuaEntity
local function target(loader) return loader.loader_container and loader.loader_container.name end

return {
  {
    -- 2.10.3
    name = "buildings: every port has its own spot on the +-2.5 lines",
    fn = function()
      for _, def in ipairs(city_defs.list) do
        local spots = {}
        for _, p in ipairs(port_layout.ports(def)) do
          local key = p.wall .. p.offset
          assert_.falsy(spots[key], def.name .. ": two ports on " .. key)
          spots[key] = true
          assert_.equals(math.abs(p.offset), 2.5, def.name .. " port off the +-2.5 lines")
        end
      end
    end,
  },
  {
    name = "buildings: a city's pipes connect at its fluid ports",
    fn = function(ctx)
      local rigs = {}
      do
        local x = X - 160
        h.clear_area({ { x - 14, -14 }, { x + 16, 16 } })
        local city = h.place_city(city_defs.entity_name("refinery"), { x + 0.5, 0.5 })
        h.pipe_at(city, "crude-oil", "input", true)
        h.pipe_at(city, "water", "input", true)
        local out = {}
        for _, fluid in ipairs({ "light-oil", "petroleum-gas" }) do
          out[fluid] = h.create("pipe", (h.port_spot(city, fluid, "output")))
        end
        h.test_power({ h.edges(city).right + 1.5, 0 }, 20e6)
        rigs[1] = { city = city, out = out }
      end
      ctx:wait(600, function() -- a craft is 5 s at half speed (2.15.7)
        for _, r in ipairs(rigs) do
          for _, fluid in ipairs({ "crude-oil", "water" }) do
            assert_.truthy(r.city.get_fluid_count(fluid) > 0, r.city.name .. ": no " .. fluid .. " came in")
          end
          for fluid, pipe in pairs(r.out) do
            assert_.truthy(pipe.get_fluid_count(fluid) > 0, r.city.name .. ": no " .. fluid .. " came out (" .. remote.call("tt-city", "info", r.city).status .. ", " .. r.city.products_finished .. " crafts)")
          end
        end
      end)
    end,
  },
  {
    -- 2.10.4
    name = "belt ports: every city has a filtered port under its wall for each item",
    fn = function(ctx)
      local placed = {}
      for i, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local x = X + 1000 + i * 24
        h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
        local city = h.place_city(name, { x + 0.5, 0.5 })
        local loaders = h.surface().find_entities_filtered({ name = "tt-belt-port", area = city.bounding_box })
        local want = 0
        for _, p in ipairs(port_layout.ports(def)) do
          if p.kind == "item" then want = want + 1 end
        end
        assert_.equals(#loaders, want, name .. " ports")
        placed[#placed + 1] = { name = name, loaders = loaders }
      end
      ctx:wait(2, function() -- a loader finds what it feeds a tick after it is built
        for _, c in ipairs(placed) do
          for _, l in ipairs(c.loaders) do
            assert_.truthy(l.get_filter(1), c.name .. ": unfiltered port")
            assert_.equals(target(l), c.name, c.name .. ": port not connected to the city")
          end
        end
      end)
    end,
  },
  {
    name = "belt ports: one yellow belt per item runs a smelting city at its full 15/s",
    fn = function(ctx)
      local x = X + 700
      h.clear_area({ { x - 14, -14 }, { x + 16, 16 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      h.belt_to_port(city, "iron-ore", "input")
      h.belt_to_port(city, "coal", "input")
      h.belt_to_port(city, "iron-plate", "output")
      ctx:wait(300, function() -- settle
        local start = city.products_finished
        ctx:wait(600, function()
          local plates = (city.products_finished - start) * 10
          assert_.truthy(plates >= 140, "plates in 10 s: " .. plates .. " (want 150)")
        end)
      end)
    end,
  },
  {
    -- 2.10.5
    name = "no inserters: one built into or out of a city is removed; others nearby stay",
    fn = function(ctx)
      local x = X + 860
      h.clear_area({ { x - 14, -14 }, { x + 16, 16 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      local e = h.edges(city)
      local N, S, E = defines.direction.north, defines.direction.south, defines.direction.east
      local cases = {
        -- into the city (picks from the north, drops on the wall)
        { "into", h.create("inserter", { x - 0.5, e.top }, { direction = N, raise_built = true }), false },
        -- out of the city (picks from the wall, drops south)
        { "out", h.create("inserter", { x - 0.5, e.bottom }, { direction = N, raise_built = true }), false },
        -- onto the belt in front of a port, not the city: fine
        { "beside", h.create("inserter", { x + 1.5, e.top - 2 }, { direction = E, raise_built = true }), true },
        -- next to the wall but working along it: fine
        { "along", h.create("inserter", { e.left - 1, 0.5 }, { direction = S, raise_built = true }), true },
      }
      ctx:wait(15, function()
        for _, c in ipairs(cases) do
          assert_.equals(c[2].valid, c[3], c[1] .. (c[3] and " inserter was removed" or " inserter was left"))
        end
      end)
    end,
  },
  {
    name = "no inserters: one a player builds into a city goes back to their inventory",
    fn = function(ctx)
      local p = assert(game.players[1])
      local x = X + 920
      h.clear_area({ { x - 14, -14 }, { x + 16, 16 } })
      local city = h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 })
      local ins = h.create("inserter", { x - 0.5, h.edges(city).top }, { direction = defines.direction.north })
      local had = p.get_item_count("inserter")
      local refused = remote.call("tt-city", "inserters_refused")
      remote.call("tt-city", "check_inserter", ins, p.index)
      ctx:wait(3, function()
        assert_.falsy(ins.valid, "inserter left")
        assert_.equals(p.get_item_count("inserter"), had + 1, "inserter not returned")
        assert_.equals(remote.call("tt-city", "inserters_refused"), refused + 1)
      end)
    end,
  },
  {
    name = "footprint: on the fixed map every city's footprint is clear of water, ore and other cities",
    fn = function()
      local surface = remote.call("tt-map", "generate", "tt-map-footprint")
      for _, c in ipairs(remote.call("tt-map", "layout").cities) do
        local x, y = c.x + 0.5, c.y + 0.5
        local area = { { x - 6.5, y - 6.5 }, { x + 6.5, y + 6.5 } }
        assert_.equals(surface.count_tiles_filtered({ area = area, collision_mask = "water_tile" }), 0, c.label .. ": water")
        assert_.equals(surface.count_entities_filtered({ area = area, type = "resource" }), 0, c.label .. ": ore")
        local cities = 0
        for _, e in pairs(surface.find_entities_filtered({ area = area })) do
          if string.sub(e.name, 1, 8) == "tt-city-" then cities = cities + 1 end
        end
        assert_.equals(cities, 1, c.label .. ": other cities in its footprint")
      end
      game.delete_surface(surface)
    end,
  },
  {
    -- 2.10.9
    name = "city window: lists every port with the belt it needs (smelting: yellow; electric smelting takes no coal)",
    fn = function()
      local x = X + 1220
      h.clear_area({ { x - 12, -12 }, { x + 50, 12 } })
      local function by(city)
        local out = {}
        for _, p in ipairs(remote.call("tt-city", "info", city).ports) do
          local key = p.kind .. "/" .. tostring(p.name) .. "/" .. p.flow
          out[key] = out[key] or {}
          table.insert(out[key], p)
        end
        return out
      end
      local t1 = by(h.place_city("tt-city-iron-smelting", { x + 0.5, 0.5 }))
      assert_.equals(t1["item/iron-ore/input"][1].belt, "yellow")
      assert_.equals(t1["item/iron-ore/input"][1].per_s, 15)
      assert_.equals(t1["item/coal/input"][1].belt, "yellow")
      assert_.equals(t1["item/iron-plate/output"][1].per_s, 15)
      assert_.falsy(t1["construction/nil/input"], "a construction port")
      local e = by(h.place_city("tt-city-electric-iron-smelting", { x + 30.5, 0.5 }))
      assert_.equals(#e["item/iron-ore/input"], 1, "electric ore ports")
      assert_.equals(e["item/iron-ore/input"][1].belt, "yellow")
      assert_.falsy(e["item/coal/input"], "electric smelting takes coal")
    end,
  },
  {
    -- 2.10.19 (user): a slow output still fills both lanes evenly
    name = "belt ports: a slow output port (depot, 1/s) fills both lanes of its belt evenly",
    fn = function(ctx)
      local x = X + 1300
      h.clear_area({ { x - 14, -14 }, { x + 16, 40 } })
      local city = h.place_city("tt-city-depot", { x + 0.5, 0.5 })
      h.test_power({ h.edges(city).right + 1.5, 0 }, 5e6)
      h.belt_to_port(city, "coal", "input")
      local s = h.port_spots(city, "tt-coal-fuel", "output")[1]
      local belts = {}
      for k = 0, 6 do belts[#belts + 1] = h.create("transport-belt", { s.pos[1], s.pos[2] + k }, { direction = s.dir }) end
      ctx:wait(60 * 16, function()
        local a, b = 0, 0
        for _, bt in ipairs(belts) do
          a = a + bt.get_transport_line(1).get_item_count()
          b = b + bt.get_transport_line(2).get_item_count()
        end
        assert_.truthy(a + b >= 10, "only " .. (a + b) .. " fuel came out")
        assert_.truthy(math.abs(a - b) <= 2, "lanes " .. a .. " / " .. b)
      end)
    end,
  },
  {
    -- playtest 2.12: picking items off a backed-up output belt let several new items onto the
    -- port at once; moving one invalidated the others' stacks, and the balancer crashed
    name = "belt ports: several new items on an output port at once are balanced without error",
    fn = function(ctx)
      local x = X + 1350
      h.clear_area({ { x - 14, -14 }, { x + 16, 40 } })
      local city = h.place_city("tt-city-depot", { x + 0.5, 0.5 })
      local s = h.port_spots(city, "tt-coal-fuel", "output")[1]
      local step = ({ [defines.direction.north] = { 0, -1 }, [defines.direction.south] = { 0, 1 },
        [defines.direction.east] = { 1, 0 }, [defines.direction.west] = { -1, 0 } })[s.dir]
      local loader = assert(city.surface.find_entity("tt-belt-port", { s.pos[1] - step[1], s.pos[2] - step[2] }), "no output port loader")
      local a, b = loader.get_transport_line(1), loader.get_transport_line(2)
      local item = { name = "tt-coal-fuel", count = 1 }
      -- one item first, so the port's tally leans to lane 1; then it is taken away
      a.insert_at_back(item)
      ctx:wait(3, function()
        a.clear()
        b.clear()
        ctx:wait(3, function()
          -- two new items at once on the busier lane
          a.insert_at_back(item)
          a.insert_at(0, item)
          local before = a.get_item_count() + b.get_item_count()
          assert_.equals(before, 2, "could not put 2 items on lane 1")
          ctx:wait(4, function()
            assert_.equals(a.get_item_count() + b.get_item_count(), before, "items lost")
            assert_.equals(b.get_item_count(), 1, "one should have moved to lane 2")
          end)
        end)
      end)
    end,
  },
  {
    name = "roof icons: every city but the silo has a large icon of its product on the roof",
    fn = function()
      for i, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local x = X + 2000 + i * 24
        h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
        local city = h.place_city(name, { x + 0.5, 0.5 })
        local roof
        for _, o in pairs(rendering.get_all_objects("tracktorio")) do
          if o.type == "sprite" and o.target.entity == city and o.x_scale > 1.5 then roof = o end
        end
        if def.kind == "silo" then
          assert_.falsy(roof, name .. " has a roof icon")
        else
          assert(roof, name .. " has no roof icon")
          assert_.equals(roof.x_scale, 1.8 * h.city_size(name) / 8, name .. " roof icon scale")
        end
      end
    end,
  },
  {
    -- 2.10.1: 2.1 loaders only connect to entities flagged "player-creation"
    name = "belt ports: a loader at the wall connects to every kind of city",
    fn = function(ctx)
      local cases = {
        { "tt-city-iron-smelting", "iron-ore" },
        { "tt-city-nuclear-power", "uranium-fuel-cell" },
        { "tt-city-rocket-silo", "processing-unit" },
        { "tt-city-research", "automation-science-pack" },
      }
      local rigs = {}
      for i, c in ipairs(cases) do
        local x = X + (i - 1) * 60
        local city, top = city_at(c[1], x)
        rigs[i] = { city = city, loader = feed({ x + 0.5, top }, c[2]), item = c[2] }
      end
      ctx:wait(120, function()
        for _, r in ipairs(rigs) do
          assert_.equals(target(r.loader), r.city.name, "loader target")
          assert_.truthy(r.city.get_item_count(r.item) > 0, r.city.name .. " got no " .. r.item)
        end
      end)
    end,
  },
  {
    name = "belt ports: a loader takes a city's output; a wrong item stays on the belt",
    fn = function(ctx)
      local x = X + 300
      local city, top, bottom = city_at("tt-city-iron-smelting", x)
      feed({ x + 0.5, top }, "iron-ore")
      feed({ x + 2.5, top }, "coal")
      local _, wrong_belt = feed({ x - 1.5, top }, "copper-plate")
      h.create("loader-1x1", { x + 0.5, bottom }, { direction = D.south, type = "output" })
      h.create("transport-belt", { x + 0.5, bottom + 1 }, { direction = D.south })
      h.create("loader-1x1", { x + 0.5, bottom + 2 }, { direction = D.south, type = "input" })
      local sink = h.create("steel-chest", { x + 0.5, bottom + 3 })
      ctx:wait(600, function()
        assert_.truthy(sink.get_item_count("iron-plate") > 0, "no plates came out")
        assert_.equals(city.get_item_count("copper-plate"), 0, "copper went into the city")
        local stuck = wrong_belt.get_transport_line(1).get_item_count() + wrong_belt.get_transport_line(2).get_item_count()
        assert_.truthy(stuck > 0, "the wrong item's belt is empty")
      end)
    end,
  },
  {
    -- how construction materials will get in: a hidden chest under the port, inside the
    -- building, takes the loader's items instead of the city
    name = "belt ports: a chest inside the building under a port takes that port's items",
    fn = function(ctx)
      local x = X + 360
      local city, top = city_at("tt-city-iron-smelting", x)
      local cx = x - 3.5
      local hidden = assert(h.surface().create_entity({ name = "wooden-chest", position = { cx, top + 1 }, force = "player" }))
      local loader = feed({ cx, top }, "iron-plate")
      ctx:wait(120, function()
        assert_.equals(target(loader), "wooden-chest", "loader target")
        assert_.truthy(hidden.get_item_count("iron-plate") > 0, "the chest got nothing")
        assert_.equals(city.get_item_count("iron-plate"), 0, "plates went into the city")
      end)
    end,
  },
}
