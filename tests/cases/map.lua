-- 1.8: scripted MVP map (built on a scratch surface with the same generator).
local assert_ = require("__train-tycoon-tests__/assert")

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
      local lake = layout().lake
      assert_.equals(surface.get_tile(lake.x, lake.y).name, "deepwater")
      assert_.truthy(surface.get_tile(lake.x + lake.radius - 1, lake.y).name == "water", "lake edge")
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
      for _, c in ipairs(l.cities) do
        assert_.truthy(dist(l.lake, c) >= 100, "lake too close to " .. c.name)
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
      assert_.equals(p.surface.name, "train-tycoon")
      assert_.equals(p.get_item_count("tt-coal-fuel"), 20)
      -- move back so later tests keep using surface 1
      p.teleport({ 0, 0 }, game.surfaces[1])
    end,
  },
}
