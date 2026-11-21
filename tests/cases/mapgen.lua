-- 2.8: procedural maps. 2.15.6: they lay out plot sites, not cities.
local assert_ = require("__tracktorio-tests__/assert")
local city_defs = require("__tracktorio__/shared/city_defs")
local h = require("__tracktorio-tests__/helpers")

local SPACING = 300

---@param plan table[]
local function plots_in(plan)
  local n = 0
  for _, c in ipairs(plan) do n = n + c.plots end
  return n
end

return {
  {
    -- 2.8.1
    name = "mapgen: chain depth comes from the recipes; the depot is shallow and the silo deepest",
    fn = function()
      local depth = city_defs.depth
      for _, def in ipairs(city_defs.list) do
        assert_.truthy(depth[def.name] and depth[def.name] >= 1, def.name .. " has no depth")
      end
      for name, want in pairs({
        -- 2.9: water comes from the water city, so its users move one level deeper
        ["depot"] = 1, ["water"] = 1, ["iron-smelting"] = 1,
        ["power"] = 2, ["refinery"] = 2, ["circuits"] = 2, ["uranium"] = 2,
        ["plastic"] = 3, ["green-science"] = 3, ["nuclear-power"] = 3,
        ["rocket-fuel-depot"] = 4,
        ["blue-science"] = 5, ["processing-units"] = 5,
        ["rocket-silo"] = 6,
      }) do
        assert_.equals(depth[name], want, name .. " depth")
      end
      for name, d in pairs(depth) do
        assert_.truthy(d <= depth["rocket-silo"], name .. " is deeper than the silo: " .. d)
      end
    end,
  },
  {
    -- 2.15.6 (user decisions): about 75 plots, sites at least the spacing apart; playtest
    -- 2.15.10: one plot per site, a starter site of 2 near spawn
    name = "mapgen: the planner lays out about 75 plots, one per site, a starter site of 2 near spawn, all apart",
    fn = function()
      for _, seed in ipairs({ 1, 42, 314159, 271828 }) do
        local plan = remote.call("tt-map", "plan", seed, SPACING)
        local n = plots_in(plan)
        assert_.truthy(n >= 75 and n <= 77, n .. " plots, seed " .. seed)
        local starters = 0
        for i, c in ipairs(plan) do
          if c.starter then
            starters = starters + 1
            assert_.equals(c.plots, 2, "starter plots")
            local d = math.sqrt(c.x ^ 2 + c.y ^ 2)
            assert_.truthy(d >= 40 and d <= 80, "starter site " .. d .. " from spawn")
          else
            assert_.equals(c.plots, 1, "plots in a site")
          end
          for j = i + 1, #plan do
            local o = plan[j]
            local d = math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)
            assert_.truthy(d >= SPACING, "sites " .. d .. " apart, seed " .. seed)
          end
        end
        assert_.equals(starters, 1, "starter sites")
      end
    end,
  },
  {
    name = "mapgen: the same seed gives the same layout and another seed a different one",
    fn = function()
      local a, b, c = remote.call("tt-map", "plan", 7), remote.call("tt-map", "plan", 7), remote.call("tt-map", "plan", 8)
      assert_.equals(serpent.line(a), serpent.line(b), "same seed differs")
      assert_.truthy(serpent.line(a) ~= serpent.line(c), "seeds 7 and 8 give the same layout")
    end,
  },
  {
    name = "mapgen: the spacing multiplier scales the layout (0.5x and 3x)",
    fn = function()
      local function reach(spacing)
        local far = 0
        for _, c in ipairs(remote.call("tt-map", "plan", 99, spacing)) do far = math.max(far, math.sqrt(c.x ^ 2 + c.y ^ 2)) end
        return far
      end
      local half, one, three = reach(SPACING / 2), reach(SPACING), reach(SPACING * 3)
      assert_.truthy(half < one and one < three, string.format("reach %d / %d / %d", half, one, three))
      assert_.truthy(three / one > 2 and three / one < 4, "3x spacing reaches " .. three / one .. "x as far")
    end,
  },
  {
    name = "mapgen: neighbour distances vary: some sites at the minimum, some well beyond it",
    fn = function()
      local near, far = 0, 0
      for _, seed in ipairs({ 3, 5, 11 }) do
        local plan = remote.call("tt-map", "plan", seed, SPACING)
        for i, c in ipairs(plan) do
          local best = math.huge
          for j, o in ipairs(plan) do
            if i ~= j then best = math.min(best, math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)) end
          end
          if best < SPACING * 1.25 then near = near + 1 end
          if best > SPACING * 1.6 then far = far + 1 end
        end
      end
      assert_.truthy(near > 0 and far > 0, string.format("%d sites near the minimum, %d well beyond", near, far))
    end,
  },
  {
    name = "mapgen: plots of a site sit side by side in a 2 x 2 grid, 10 tiles of ground between",
    fn = function()
      for n = 1, 4 do
        local o = remote.call("tt-map", "offsets", n)
        assert_.equals(#o, n, n .. " offsets")
        for i = 1, #o do
          for j = i + 1, #o do
            local dx, dy = math.abs(o[i][1] - o[j][1]), math.abs(o[i][2] - o[j][2])
            assert_.truthy(math.max(dx, dy) >= 22, "plots " .. i .. " and " .. j .. " overlap or touch")
          end
        end
      end
    end,
  },
  {
    -- 2.8.3
    name = "mapgen: a spot on an island is not mainland; open land and a lake shore are",
    fn = function()
      local s = h.surface()
      local X, Y = 20000, 0
      h.clear_area({ { X - 140, Y - 140 }, { X + 140, Y + 140 } })
      local tiles = {}
      for x = X - 130, X + 130 do
        for y = Y - 130, Y + 130 do
          local d = math.sqrt((x - X) ^ 2 + (y - Y) ^ 2)
          if d > 30 and d < 120 then tiles[#tiles + 1] = { name = "water", position = { x, y } } end
        end
      end
      s.set_tiles(tiles)
      assert_.falsy(remote.call("tt-map", "mainland", s.name, X + 0.5, Y + 0.5), "island counted as mainland")
      -- a shore: water on one side only
      local fill = {}
      for _, t in ipairs(tiles) do
        if t.position[1] < X - 20 then fill[#fill + 1] = t else fill[#fill + 1] = { name = "grass-1", position = t.position } end
      end
      s.set_tiles(fill)
      assert_.truthy(remote.call("tt-map", "mainland", s.name, X + 0.5, Y + 0.5), "lake shore not mainland")
      local grass = {}
      for _, t in ipairs(tiles) do grass[#grass + 1] = { name = "grass-1", position = t.position } end
      s.set_tiles(grass)
      assert_.truthy(remote.call("tt-map", "mainland", s.name, X + 0.5, Y + 0.5), "open land not mainland")
    end,
  },
  {
    name = "mapgen: on vanilla terrain every site gets dry, clear mainland, its plots painted and no ore on them",
    fn = function()
      -- 2.1: game.default_map_gen_settings mixes every planet (oil ocean, lava, ice); use
      -- Nauvis's own
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 314159
      mgs.no_enemies_mode = true
      local s = game.create_surface("tt-mapgen-vanilla", mgs)
      local prof = helpers.create_profiler()
      local result = remote.call("tt-map", "place_procedural", s.name, 314159, SPACING)
      prof.stop()
      log({ "", "mapgen: placing the layout took ", prof }) ---@diagnostic disable-line: assign-type-mismatch
      assert_.equals(#result.missing, 0, "no land for " .. serpent.line(result.missing))
      assert_.truthy(plots_in(result.placed) >= 75, "plots placed")
      local moved = 0
      for i, c in ipairs(result.placed) do
        assert_.truthy(remote.call("tt-map", "mainland", s.name, c.x + 0.5, c.y + 0.5), c.label .. " on an island")
        for _, o in ipairs(remote.call("tt-map", "offsets", c.plots)) do
          local px, py = c.x + o[1], c.y + o[2]
          local area = { { px - 6, py - 6 }, { px + 6, py + 6 } }
          assert_.equals(s.count_tiles_filtered({ area = area, name = { "tt-plot", "tt-plot-border" } }), 144, c.label .. " plot tiles")
          assert_.equals(s.count_entities_filtered({ area = area, type = { "resource", "cliff", "tree", "simple-entity" } }), 0,
            c.label .. " has ore, cliffs, trees or rocks on a plot")
          assert_.truthy(s.can_place_entity({ name = "tt-city-depot", position = { px, py }, force = "player",
            build_check_type = defines.build_check_type.manual }), c.label .. ": a city can't be built on its plot")
        end
        local d = math.sqrt((c.x - c.planned.x) ^ 2 + (c.y - c.planned.y) ^ 2)
        local dr = math.abs(math.sqrt(c.x ^ 2 + c.y ^ 2) - math.sqrt(c.planned.x ^ 2 + c.planned.y ^ 2))
        assert_.truthy(d <= 330 or dr <= 330, c.label .. " moved " .. d .. ", " .. dr .. " in distance from spawn")
        moved = math.max(moved, d)
        for j = i + 1, #result.placed do
          local o = result.placed[j]
          local apart = math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)
          assert_.truthy(apart >= SPACING, c.label .. " and " .. o.label .. " " .. apart .. " apart")
        end
      end
      log("mapgen: vanilla terrain, furthest move from the planned spot " .. math.floor(moved))
      game.delete_surface(s)
    end,
  },
  {
    -- 2.8.4
    name = "mapgen: the test scenario is not freeplay, so Nauvis is left alone",
    fn = function()
      assert_.falsy(remote.call("tt-nauvis", "is_freeplay"), "test scenario taken for freeplay")
      -- (other tests build cities on Nauvis by hand, so ask the mod, not the map)
      assert_.falsy(remote.call("tt-nauvis", "is_managed", "nauvis"), "Nauvis taken over")
    end,
  },
  {
    -- 2.8.10
    name = "mapgen: the Tracktorio scenario gives the starting coal fuel; freeplay gives its own items",
    fn = function()
      assert_.falsy(remote.call("tt-nauvis", "is_own_scenario"), "the test scenario taken for Tracktorio")
      local p = assert(game.players[1])
      local inv = assert(p.get_main_inventory())
      inv.clear()
      remote.call("tt-nauvis", "player_created_as", "scenario", p.index)
      assert_.equals(inv.get_item_count("tt-coal-fuel"), 20, "coal fuel in the scenario")
      inv.clear()
      remote.call("tt-nauvis", "player_created_as", "freeplay", p.index)
      assert_.equals(inv.get_item_count(), 0, "items given in freeplay (freeplay gives its own)")
    end,
  },
  {
    name = "mapgen: a New Game turns off the crash site and the intro and starts with coal fuel only",
    fn = function()
      local calls = {}
      local function rec(name) return function(v) calls[name] = v end end
      remote.add_interface("freeplay", {
        set_disable_crashsite = rec("crashsite"), set_skip_intro = rec("intro"),
        set_created_items = rec("created"), set_respawn_items = rec("respawn"),
      })
      local ok, err = pcall(remote.call, "tt-nauvis", "setup_freeplay")
      remote.remove_interface("freeplay")
      assert(ok, err)
      assert_.equals(calls.crashsite, true, "crash site")
      assert_.equals(calls.intro, true, "intro")
      assert_.equals(serpent.line(calls.created), serpent.line({ ["tt-coal-fuel"] = 20 }), "starting items")
      assert_.equals(table_size(calls.respawn), 0, "respawn items")
    end,
  },
  {
    name = "mapgen: a prepared Nauvis has no biters (also in later chunks) and no resources near spawn",
    fn = function(ctx)
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 271828
      mgs.no_enemies_mode = false
      local s = game.create_surface("tt-mapgen-nauvis", mgs)
      local clear = remote.call("tt-nauvis", "start_clear")
      s.request_to_generate_chunks({ 0, 0 }, math.ceil(clear / 32) + 4)
      s.force_generate_chunk_requests()
      local near = { { -clear, -clear }, { clear, clear } }
      local before = s.count_entities_filtered({ area = near, type = "resource" })
      assert_.truthy(before > 0, "the seed has no resources near spawn to clear")
      local result = remote.call("tt-nauvis", "prepare", s.name, 271828, SPACING)
      assert_.equals(#result.missing, 0, "missing " .. serpent.line(result.missing))
      assert_.truthy(s.peaceful_mode, "not peaceful")
      assert_.falsy(game.map_settings.enemy_expansion.enabled, "expansion on")
      assert_.equals(s.count_entities_filtered({ force = "enemy" }), 0, "enemies left")
      for _, r in pairs(s.find_entities_filtered({ area = near, type = "resource" })) do
        local d = math.sqrt(r.position.x ^ 2 + r.position.y ^ 2)
        assert_.truthy(d > clear, r.name .. " " .. math.floor(d) .. " tiles from spawn")
      end
      local outer = s.count_entities_filtered({ area = { { -clear - 120, -clear - 120 }, { clear + 120, clear + 120 } }, type = "resource" })
      local starter
      for _, c in ipairs(result.placed) do if c.starter then starter = c end end
      assert_.truthy(starter and math.sqrt(starter.x ^ 2 + starter.y ^ 2) < 200, "starter site not near spawn")
      -- chunks generated later are cleaned as they appear
      s.request_to_generate_chunks({ 2000, 2000 }, 4)
      s.force_generate_chunk_requests()
      ctx:wait(2, function()
        assert_.equals(s.count_entities_filtered({ force = "enemy" }), 0, "enemies in later chunks")
        log("mapgen: resources " .. before .. " near spawn before, " .. outer .. " within " .. (clear + 120) .. " after")
        game.delete_surface(s)
      end)
    end,
  },
  {
    -- follow-up to 2.8.4 (user question): does the generator still place nests after
    -- prepare, with the clean-up only hiding them? Same seed and area on two surfaces: one
    -- untouched (nests expected, so the area is a fair test), one prepared.
    name = "mapgen: after prepare the map generator places no biter nests at all",
    fn = function(ctx)
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 141421
      mgs.no_enemies_mode = false
      local area = { { 1500, 1500 }, { 2500, 2500 } }
      local control = game.create_surface("tt-mapgen-biters-on", mgs)
      control.request_to_generate_chunks({ 2000, 2000 }, 16)
      control.force_generate_chunk_requests()
      local nests = control.count_entities_filtered({ area = area, type = "unit-spawner" })
      game.delete_surface(control)
      assert_.truthy(nests > 0, "the control area has no nests, so it proves nothing")
      local s = game.create_surface("tt-mapgen-biters-off", mgs)
      remote.call("tt-nauvis", "prepare", s.name, 141421, SPACING)
      local before = remote.call("tt-nauvis", "removed_later", s.name)
      s.request_to_generate_chunks({ 2000, 2000 }, 16)
      s.force_generate_chunk_requests()
      ctx:wait(2, function()
        local removed = remote.call("tt-nauvis", "removed_later", s.name) - before
        log("mapgen: nests with biters on " .. nests .. "; enemies removed from the same area after prepare " .. removed)
        assert_.equals(removed, 0, "enemies the generator placed after prepare")
        assert_.equals(s.count_entities_filtered({ force = "enemy" }), 0, "enemies left")
        game.delete_surface(s)
      end)
    end,
  },
  {
    -- 2.8.6: start-up stays fast at the widest spacing. A profiler can't be read in Lua, so
    -- the time is logged as a TT-TIMING line that run-tests.ps1 checks against its budget;
    -- the chunk count is checked here.
    name = "mapgen: laying out Nauvis at 3x spacing generates few chunks and stays under 10 s",
    fn = function()
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 577215
      local s = game.create_surface("tt-mapgen-wide", mgs)
      local prof = helpers.create_profiler()
      local result = remote.call("tt-nauvis", "prepare", s.name, 577215, SPACING * 3)
      prof.stop()
      log({ "", "TT-TIMING budget_ms=10000 name=layout-3x ", prof }) ---@diagnostic disable-line: assign-type-mismatch
      assert_.equals(#result.missing, 0, "missing " .. serpent.line(result.missing))
      local chunks = 0
      for chunk in s.get_chunks() do
        if s.is_chunk_generated(chunk) then chunks = chunks + 1 end
      end
      log("mapgen: 3x layout generated " .. chunks .. " chunks")
      assert_.truthy(chunks <= #result.placed * 9 + 100, chunks .. " chunks generated for " .. #result.placed .. " sites")
      local far = 0
      for _, c in ipairs(result.placed) do far = math.max(far, math.sqrt(c.x ^ 2 + c.y ^ 2)) end
      assert_.truthy(far > 3000, "furthest site only " .. far)
      game.delete_surface(s)
    end,
  },
  {
    -- 2.8.5 (changed by the user in playtest 2.8.7: on the map from the start); 2.15.6 sites
    name = "mapgen: every plot site has its map tag from the start, naming the city built on it; the land between stays dark",
    fn = function(ctx)
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 161803
      local s = game.create_surface("tt-mapgen-tags", mgs)
      local result = remote.call("tt-nauvis", "prepare", s.name, 161803, SPACING)
      local force = game.forces["player"]
      ctx:wait_until(function() return #force.find_chart_tags(s) >= #result.placed end, 600, function()
        local tags = force.find_chart_tags(s)
        assert_.equals(#tags, #result.placed, "one tag per site")
        for _, c in ipairs(result.placed) do
          local found = force.find_chart_tags(s, { { c.x - 1, c.y - 1 }, { c.x + 2, c.y + 2 } })
          assert_.equals(#found, 1, c.label .. " tags")
          assert_.equals(found[1].text, c.label, "tag text")
        end
        -- only the sites are charted: halfway between the starter site and the next is dark
        local a, b = result.placed[1], result.placed[2]
        local mx, my = (a.x + b.x) / 2, (a.y + b.y) / 2
        assert_.falsy(force.is_chunk_charted(s, { math.floor(mx / 32), math.floor(my / 32) }), "land between sites charted")
        -- charting a site again adds no second tag
        local c = result.placed[#result.placed]
        force.chart(s, { { c.x - 8, c.y - 8 }, { c.x + 8, c.y + 8 } })
        ctx:wait(60, function()
          assert_.equals(#force.find_chart_tags(s), #result.placed, "tags after charting again")
          -- playtest 2.15.10: a site's tag names the city built on it, and goes back when
          -- it is removed; a tag the player edited is left alone
          local function tag_of(site) return force.find_chart_tags(s, { { site.x - 1, site.y - 1 }, { site.x + 2, site.y + 2 } })[1] end
          local function build(name, site, o)
            return assert(s.create_entity({ name = name, position = { site.x + o[1], site.y + o[2] }, force = "player", raise_built = true }))
          end
          local single, starter
          for _, p in ipairs(result.placed) do
            if p.starter then starter = p elseif not single then single = p end
          end
          local steel = build("tt-city-steel", single, { 0, 0 })
          assert_.equals(tag_of(single).text, "Steel city", "single plot tag")
          assert_.equals(tag_of(single).icon.name, "tt-city-steel", "single plot icon")
          local offs = remote.call("tt-map", "offsets", 2)
          build("tt-city-power", starter, offs[1])
          assert_.equals(tag_of(starter).text, "Power city + free plot", "starter, one built")
          build("tt-city-water", starter, offs[2])
          assert_.equals(tag_of(starter).text, "Power city + Water city", "starter, both built")
          -- the player names another site's tag; building there leaves their name
          local other = result.placed[#result.placed]
          tag_of(other).text = "My steel"
          build("tt-city-steel", other, { 0, 0 })
          assert_.equals(tag_of(other).text, "My steel", "edited tag kept")
          steel.destroy()
          ctx:wait(2, function()
            assert_.equals(tag_of(single).text, single.label, "tag after the city is removed")
            assert_.equals(tag_of(single).icon.name, "refined-hazard-concrete", "icon after the city is removed")
            game.delete_surface(s)
          end)
        end)
      end)
    end,
  },}
