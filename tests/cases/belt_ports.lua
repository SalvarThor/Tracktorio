-- 2.10: belt ports. A port is a hidden loader at the city wall; these tests pin down what
-- 2.1 loaders do with cities.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

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
  return city, 0.5 - half - 0.5, 0.5 + half + 0.5
end

---@param loader LuaEntity
local function target(loader) return loader.loader_container and loader.loader_container.name end

return {
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
