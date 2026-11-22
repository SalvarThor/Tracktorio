-- 2.15.3: plots. Cities are items the player builds, and only on plot tiles.
-- 2.15.4: building (by hand, ghost, robot, upgrade planner) sets a city up; mining loses
-- its contents.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")
local city_defs = require("__tracktorio__/shared/city_defs")

local X = 60000
local PLOT, BORDER, LAYER = "tt-plot", "tt-plot-border", "tt_plot"

--- Paint a 12x12 plot whose centre is the tile corner (cx, cy): a border ring around the
--- inside, as map generation does.
---@param cx integer
---@param cy integer
local function paint_plot(cx, cy)
  local tiles = {}
  for x = cx - 6, cx + 5 do
    for y = cy - 6, cy + 5 do
      local edge = x == cx - 6 or x == cx + 5 or y == cy - 6 or y == cy + 5
      tiles[#tiles + 1] = { name = edge and BORDER or PLOT, position = { x, y } }
    end
  end
  h.surface().set_tiles(tiles)
end

local RED = defines.wire_connector_id.circuit_red

--- Build a city on a fresh plot as a player's build would: create_entity raising
--- script_raised_built (the same handler as on_built_entity and on_robot_built_entity).
---@param name string
---@param cx integer plot centre (tile corner)
local function build(name, cx)
  h.clear_area({ { cx - 14, -14 }, { cx + 14, 16 } })
  paint_plot(cx, 0)
  return assert(h.surface().create_entity({ name = name, position = { cx, 0 }, force = "player", raise_built = true }))
end

--- What is set up around a city: { ports, point, beacon, generator, tracked }.
---@param city LuaEntity
local function parts(city)
  local area = city.bounding_box
  local s = h.surface()
  return {
    ports = s.count_entities_filtered({ area = area, name = "tt-belt-port" }),
    points = s.count_entities_filtered({ area = area, name = "tt-signal-point" }),
    beacons = s.count_entities_filtered({ area = area, name = "tt-throttle-beacon" }),
    generators = s.count_entities_filtered({ area = area, name = "tt-power-generator" }),
    radars = s.count_entities_filtered({ area = area, name = "tt-hidden-radar" }),
  }
end

---@param name string
---@param x number
---@param y number
local function can_build(name, x, y)
  return h.surface().can_place_entity({ name = name, position = { x, y }, force = "player",
    build_check_type = defines.build_check_type.manual })
end

return {
  {
    name = "plots: both plot tiles carry the plot layer and can't be mined",
    fn = function()
      for _, name in ipairs({ PLOT, BORDER }) do
        local t = assert(prototypes.tile[name], "no tile " .. name)
        assert_.truthy(t.collision_mask.layers[LAYER], name .. " lacks the plot layer")
        assert_.falsy(t.mineable_properties.minable, name .. " is minable")
      end
    end,
  },
  {
    name = "plots: no tile item (concrete, landfill, ...) can be placed on a plot",
    fn = function()
      local n = 0
      for name, item in pairs(prototypes.item) do
        local t = item.place_as_tile_result
        if t then
          n = n + 1
          assert_.truthy(t.condition.layers[LAYER], name .. " can be placed on a plot")
        end
      end
      assert_.truthy(n >= 3, "only " .. n .. " tile items")
    end,
  },
  {
    name = "plots: a city can be built on a plot and nowhere else",
    fn = function()
      h.clear_area({ { X - 30, -20 }, { X + 30, 20 } })
      paint_plot(X, 0)
      for _, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        -- the 9x9 silo centres on a tile, the 12x12 cities on a tile corner
        local cx = def.kind == "silo" and X + 0.5 or X
        local cy = def.kind == "silo" and 0.5 or 0
        assert_.truthy(can_build(name, cx, cy), name .. " can't be built on its plot")
        assert_.falsy(can_build(name, cx + 20, cy), name .. " can be built off the plot")
        if def.kind ~= "silo" then
          assert_.falsy(can_build(name, cx + 1, cy), name .. " can be built half off the plot")
        end
      end
    end,
  },
  {
    name = "plots: every city kind has an item and a free build recipe; coal smelting upgrades to electric",
    fn = function()
      for _, def in ipairs(city_defs.list) do
        local name = city_defs.entity_name(def.name)
        local item = assert(prototypes.item[name], name .. " has no item")
        assert_.equals(item.place_result.name, name, name .. " item places")
        local recipe = assert(prototypes.recipe["tt-build-" .. name], name .. " has no build recipe")
        assert_.equals(#recipe.ingredients, 0, name .. " build recipe has ingredients")
        assert_.equals(recipe.products[1].name, name, name .. " build recipe makes")
        local proto = prototypes.entity[name]
        assert_.equals(proto.mineable_properties.products[1].name, name, name .. " mines into its item")
      end
      for _, metal in ipairs({ "iron", "copper" }) do
        local coal = prototypes.entity["tt-city-" .. metal .. "-smelting"]
        assert_.equals(coal.next_upgrade and coal.next_upgrade.name, "tt-city-electric-" .. metal .. "-smelting", metal)
      end
    end,
  },
  {
    name = "build: a city the player builds is set up like a placed one: ports, signal point, throttle, generator",
    fn = function()
      local city = build("tt-city-iron-smelting", X + 100)
      assert_.truthy(remote.call("tt-city", "has_window", city), "no window")
      assert_.falsy(city.operable, "operable")
      assert_.truthy(city.minable_flag, "not minable")
      local n = parts(city)
      assert_.equals(n.ports, 3, "belt ports")
      assert_.equals(n.points, 1, "signal points")
      assert_.equals(n.beacons, 1, "throttle beacons")
      assert_.equals(n.radars, 1, "city radar")
      local power = build("tt-city-power", X + 140)
      assert_.equals(parts(power).generators, 1, "power city generator")
    end,
  },
  {
    name = "build: a ghost revived (as a robot builds it) is set up too",
    fn = function()
      local cx = X + 180
      h.clear_area({ { cx - 14, -14 }, { cx + 14, 16 } })
      paint_plot(cx, 0)
      local ghost = assert(h.surface().create_entity({ name = "entity-ghost", inner_name = "tt-city-depot",
        position = { cx, 0 }, force = "player" }))
      local _, city = ghost.revive({ raise_revive = true })
      assert(city and city.valid, "ghost did not revive")
      assert_.truthy(remote.call("tt-city", "service_status", city), "the depot has no service port")
      assert_.equals(parts(city).points, 1, "signal points")
    end,
  },
  {
    name = "build: mining a city gives back the city and nothing inside it; its parts go",
    fn = function(ctx)
      local city = build("tt-city-iron-smelting", X + 220)
      city.get_inventory(defines.inventory.crafter_input).insert({ name = "iron-ore", count = 30 })
      city.get_inventory(defines.inventory.crafter_output).insert({ name = "iron-plate", count = 20 })
      local area = city.bounding_box
      local p = assert(game.players[1])
      local inv = assert(p.get_main_inventory())
      local ore, plates, items = inv.get_item_count("iron-ore"), inv.get_item_count("iron-plate"),
        inv.get_item_count("tt-city-iron-smelting")
      assert_.truthy(p.mine_entity(city, true), "could not mine the city")
      assert_.equals(inv.get_item_count("tt-city-iron-smelting"), items + 1, "city item")
      assert_.equals(inv.get_item_count("iron-ore"), ore, "ore came out of the city")
      assert_.equals(inv.get_item_count("iron-plate"), plates, "plates came out of the city")
      ctx:wait(2, function()
        local s = h.surface()
        assert_.equals(s.count_entities_filtered({ area = area, name = { "tt-belt-port", "tt-signal-point", "tt-throttle-beacon", "tt-hidden-radar" } }), 0,
          "parts left behind")
      end)
    end,
  },
  {
    name = "build: the upgrade planner's swap to electric smelting keeps the wires and leaves one set of parts",
    fn = function()
      local cx = X + 260
      local city = build("tt-city-iron-smelting", cx)
      local pole = h.create("medium-electric-pole", { cx + 0.5, 9.5 })
      local point = assert(remote.call("tt-city", "signal_points", city).stock)
      assert(point.get_wire_connector(RED, true).connect_to(pole.get_wire_connector(RED, true), false), "wire")
      local new = assert(h.surface().create_entity({ name = "tt-city-electric-iron-smelting", position = { cx, 0 },
        force = "player", fast_replace = true, player = game.players[1], raise_built = true, spill = false }),
        "the electric city did not replace the coal one")
      assert_.falsy(city.valid, "the old city is still there")
      local n = parts(new)
      assert_.equals(n.ports, 2, "belt ports (ore in, plates out)")
      assert_.equals(n.points, 1, "signal points")
      assert_.equals(n.beacons, 1, "throttle beacons")
      assert_.equals(n.radars, 1, "city radar")
      local new_point = assert(remote.call("tt-city", "signal_points", new).stock)
      assert_.equals(new_point.get_wire_connector(RED, true).connection_count, 1, "the wire was lost")
    end,
  },
  {
    -- user, playtest 2.15.10: zoom in on any city from the map
    name = "build: a city's hidden radar charts the chunks around it, without power, and no further",
    fn = function(ctx)
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 4242
      local s = game.create_surface("tt-radar-test", mgs)
      s.request_to_generate_chunks({ 0, 0 }, 1)
      s.force_generate_chunk_requests()
      local city = assert(s.create_entity({ name = "tt-city-iron-smelting", position = { 0, 0 }, force = "player", raise_built = true }))
      local force = game.forces["player"]
      assert_.equals(s.count_entities_filtered({ area = city.bounding_box, name = "tt-hidden-radar" }), 1, "city radar")
      ctx:wait(600, function()
        assert_.truthy(force.is_chunk_charted(s, { 0, 0 }), "the city's chunk is not charted")
        assert_.truthy(force.is_chunk_charted(s, { 2, -2 }), "a chunk two away is not charted")
        assert_.falsy(force.is_chunk_charted(s, { 6, 0 }), "a chunk six away is charted")
        game.delete_surface(s)
      end)
    end,
  },
  {
    -- 2.15.5 (table agreed with the user)
    name = "research: the starting cities can be built at once; each other city is unlocked by its technology",
    fn = function()
      local force = game.forces["player"]
      local start = { "depot", "power", "water", "iron-smelting", "copper-smelting", "red-science", "research", "circuits" }
      for _, n in ipairs(start) do
        local r = assert(force.recipes["tt-build-tt-city-" .. n], "no build recipe for " .. n)
        assert_.truthy(r.enabled, n .. " can't be built from the start")
      end
      for _, def in ipairs(city_defs.list) do
        local recipe = "tt-build-" .. city_defs.entity_name(def.name)
        if def.unlock then
          local tech = assert(force.technologies[def.unlock], "no technology " .. def.unlock)
          assert_.falsy(tech.prototype.hidden, def.unlock .. " is hidden")
          local found = false
          for _, e in ipairs(tech.prototype.effects) do
            if e.type == "unlock-recipe" and e.recipe == recipe then found = true end
          end
          assert_.truthy(found, def.unlock .. " does not unlock " .. def.name)
          if not tech.researched then
            assert_.falsy(force.recipes[recipe].enabled, def.name .. " can be built before " .. def.unlock)
          end
        else
          assert_.truthy(force.recipes[recipe].enabled, def.name .. " is not a starting city but has no technology")
        end
      end
      -- researching one unlocks it
      local steel = force.technologies["steel-processing"]
      local was = steel.researched
      steel.researched = true
      assert_.truthy(force.recipes["tt-build-tt-city-steel"].enabled, "steel city still locked")
      steel.researched = was
      if not was then force.recipes["tt-build-tt-city-steel"].enabled = false end
    end,
  },
  {
    -- 2.15.9: the point of plots: a product from several cities
    name = "build: two smelting cities of one kind on neighbouring plots each run on their own belts",
    fn = function(ctx)
      local cx = X + 320
      h.clear_area({ { cx - 30, -20 }, { cx + 30, 24 } })
      local made = {}
      for i, dx in ipairs({ -11, 11 }) do
        paint_plot(cx + dx, 0)
        local city = assert(h.surface().create_entity({ name = "tt-city-iron-smelting", position = { cx + dx, 0 },
          force = "player", raise_built = true }))
        h.belt_to_port(city, "iron-ore", "input")
        h.belt_to_port(city, "coal", "input")
        h.belt_to_port(city, "iron-plate", "output")
        made[i] = city
      end
      assert_.truthy(made[1].unit_number ~= made[2].unit_number, "one city")
      ctx:wait(60 * 5, function() -- belts fill
        local start = { made[1].products_finished, made[2].products_finished }
        ctx:wait(60 * 8, function()
          for i, city in ipairs(made) do
            local n = city.products_finished - start[i]
            -- 0.75 crafts/s at full speed: 6 in 8 s
            assert_.truthy(n >= 5, "city " .. i .. " made " .. n .. " in 8 s")
            assert_.equals(remote.call("tt-city", "info", city).status, "running", "city " .. i)
          end
        end)
      end)
    end,
  },
  {
    -- playtest 2.15.10: a site's map tag names the city built on it (tag text is not
    -- localised, so the names live in scripts/map.lua)
    name = "plots: every buildable city kind has a map tag name",
    fn = function()
      local names = remote.call("tt-map", "tag_names")
      for name, recipe in pairs(prototypes.recipe) do
        if string.sub(name, 1, #"tt-build-") == "tt-build-" then
          local city = recipe.products[1].name
          assert_.truthy(names[city], city .. " has no tag name")
        end
      end
    end,
  },
}
