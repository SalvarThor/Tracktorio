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
    name = "buildings: 8x8 / 12x12 / 16x16 by tier (silo 9x9); ports keep one spot each at every tier",
    fn = function()
      for _, def in ipairs(city_defs.list) do
        local spots = {}
        for _, p in ipairs(port_layout.ports(def)) do
          local key = p.wall .. p.offset
          assert_.falsy(spots[key], def.name .. ": two ports on " .. key)
          spots[key] = true
          -- tier 1 ports only on lines every tier has
          if p.tiers[1] then assert_.equals(math.abs(p.offset), 2.5, def.name .. " tier 1 port off the shared lines") end
          assert_.truthy(math.abs(p.offset) <= 5.5, def.name .. " port beyond the 16x16 spots")
        end
        for tier = 1, #def.tiers do
          local name = city_defs.entity_name(def.name, tier)
          local want = def.kind == "silo" and 9 or ({ 8, 12, 16 })[tier]
          assert_.equals(h.city_size(name), want, name .. " size")
        end
      end
    end,
  },
  {
    name = "buildings: a city's pipes connect at its fluid ports, at every tier",
    fn = function(ctx)
      local rigs = {}
      for tier = 1, 3 do
        local x = X - 200 + tier * 40
        h.clear_area({ { x - 14, -14 }, { x + 16, 16 } })
        local city = h.place_city(city_defs.entity_name("refinery", tier), { x + 0.5, 0.5 })
        h.pipe_at(city, "crude-oil", "input", true)
        h.pipe_at(city, "water", "input", true)
        local out = {}
        for _, fluid in ipairs({ "light-oil", "petroleum-gas" }) do
          out[fluid] = h.create("pipe", (h.port_spot(city, fluid, "output")))
        end
        h.test_power({ h.edges(city).right + 1.5, 0 }, 20e6)
        rigs[tier] = { city = city, out = out }
      end
      ctx:wait(300, function()
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
    name = "belt ports: every tier of every city has a filtered port under its wall for each item",
    fn = function(ctx)
      local placed, i = {}, 0
      for _, def in ipairs(city_defs.list) do
        for tier = 1, #def.tiers do
          local name = city_defs.entity_name(def.name, tier)
          local x = X + 1000 + i * 24
          i = i + 1
          h.clear_area({ { x - 10, -10 }, { x + 11, 11 } })
          local city = h.place_city(name, { x + 0.5, 0.5 })
          local loaders = h.surface().find_entities_filtered({ name = "tt-belt-port", area = city.bounding_box })
          local want = 0
          for _, p in ipairs(port_layout.ports(def)) do
            if p.kind == "item" and p.tiers[tier] then want = want + 1 end
          end
          assert_.equals(#loaders, want, name .. " ports")
          placed[#placed + 1] = { name = name, loaders = loaders }
        end
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
    name = "belt ports: one yellow belt per item runs a tier 1 smelting city at its full 15/s",
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
    name = "belt ports: tier 3 smelting has two ports per item; two blue belts each way run it at 60/s",
    fn = function(ctx)
      local x = X + 760
      h.clear_area({ { x - 16, -16 }, { x + 18, 18 } })
      local city = h.place_city("tt-city-iron-smelting-t3", { x + 0.5, 0.5 })
      assert_.equals(#h.port_spots(city, "iron-ore", "input"), 2, "ore ports")
      assert_.equals(#h.port_spots(city, "iron-plate", "output"), 2, "plate ports")
      h.belt_to_port(city, "iron-ore", "input", "express-transport-belt")
      h.belt_to_port(city, "iron-plate", "output", "express-transport-belt")
      h.test_power({ h.edges(city).right + 1.5, 0 }, 20e6)
      ctx:wait(300, function()
        local start = city.products_finished
        ctx:wait(600, function()
          local plates = (city.products_finished - start) * 10
          assert_.truthy(plates >= 560, "plates in 10 s: " .. plates .. " (want 600)")
        end)
      end)
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
