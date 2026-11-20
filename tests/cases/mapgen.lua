-- 2.8: procedural maps.
local assert_ = require("__tracktorio-tests__/assert")
local city_defs = require("__tracktorio__/shared/city_defs")
local h = require("__tracktorio-tests__/helpers")

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
        ["depot"] = 1, ["power"] = 1, ["iron-smelting"] = 1, ["refinery"] = 1,
        ["circuits"] = 2, ["uranium"] = 2, ["plastic"] = 2,
        ["green-science"] = 3, ["nuclear-power"] = 3, ["rocket-fuel-depot"] = 3,
        ["blue-science"] = 4, ["processing-units"] = 4,
        ["rocket-silo"] = 5,
      }) do
        assert_.equals(depth[name], want, name .. " depth")
      end
      for name, d in pairs(depth) do
        assert_.truthy(d <= depth["rocket-silo"], name .. " is deeper than the silo: " .. d)
      end
    end,
  },
  {
    -- 2.8.2
    name = "mapgen: the planner places every city once, the depot near spawn, all at least the spacing apart",
    fn = function()
      local want = #remote.call("tt-map", "layout").cities
      assert_.equals(remote.call("tt-map", "spacing"), 1000, "default spacing")
      for _, seed in ipairs({ 1, 42, 123456789, 4000000000 }) do
        local plan = remote.call("tt-map", "plan", seed)
        assert_.equals(#plan, want, "cities planned, seed " .. seed)
        local depots = 0
        for i, a in ipairs(plan) do
          assert_.truthy(a.x == math.floor(a.x) and a.y == math.floor(a.y), "not on whole tiles")
          if a.name == "tt-city-depot" then
            depots = depots + 1
            local d = math.sqrt(a.x ^ 2 + a.y ^ 2)
            assert_.truthy(d >= 35 and d <= 90, "depot " .. d .. " from spawn, seed " .. seed)
          end
          for j = i + 1, #plan do
            local b = plan[j]
            local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
            assert_.truthy(d >= 1000, a.label .. " and " .. b.label .. " only " .. d .. " apart, seed " .. seed)
          end
        end
        assert_.equals(depots, 1, "depots")
      end
    end,
  },
  {
    name = "mapgen: the same seed gives the same layout and another seed a different one",
    fn = function()
      local a, b, c = remote.call("tt-map", "plan", 7), remote.call("tt-map", "plan", 7), remote.call("tt-map", "plan", 8)
      assert_.equals(serpent.line(a), serpent.line(b), "same seed")
      assert_.truthy(serpent.line(a) ~= serpent.line(c), "seeds 7 and 8 gave the same layout")
    end,
  },
  {
    name = "mapgen: the spacing multiplier scales the layout (0.5x and 3x)",
    fn = function()
      local function stats(spacing)
        local plan = remote.call("tt-map", "plan", 99, spacing)
        local min_pair, max_r = math.huge, 0
        for i, a in ipairs(plan) do
          max_r = math.max(max_r, math.sqrt(a.x ^ 2 + a.y ^ 2))
          for j = i + 1, #plan do
            min_pair = math.min(min_pair, math.sqrt((a.x - plan[j].x) ^ 2 + (a.y - plan[j].y) ^ 2))
          end
        end
        return min_pair, max_r
      end
      local p1, r1 = stats(1000)
      local p05, r05 = stats(500)
      local p3, r3 = stats(3000)
      assert_.truthy(p05 >= 500 and p3 >= 3000 and p1 >= 1000, "pairs " .. p05 .. " / " .. p1 .. " / " .. p3)
      assert_.truthy(r05 < r1 and r1 < r3, "radius " .. r05 .. " / " .. r1 .. " / " .. r3)
      -- recorded for tuning: how big the map gets
      log("mapgen: furthest city at spacing 500/1000/3000: " .. math.floor(r05) .. " / " .. math.floor(r1) .. " / " .. math.floor(r3))
    end,
  },
  {
    name = "mapgen: deeper cities sit further from spawn on average (over 10 seeds)",
    fn = function()
      local sum, n = {}, {}
      for seed = 1, 10 do
        for _, c in ipairs(remote.call("tt-map", "plan", seed)) do
          if c.name ~= "tt-city-depot" then
            sum[c.depth] = (sum[c.depth] or 0) + math.sqrt(c.x ^ 2 + c.y ^ 2)
            n[c.depth] = (n[c.depth] or 0) + 1
          end
        end
      end
      local mean = {}
      for d in pairs(sum) do mean[d] = sum[d] / n[d] end
      log("mapgen: mean distance by depth " .. serpent.line(mean))
      assert_.truthy(mean[5] > mean[1] * 1.3, "depth 5 " .. mean[5] .. " vs depth 1 " .. mean[1])
      assert_.truthy(mean[3] > mean[1], "depth 3 " .. mean[3] .. " vs depth 1 " .. mean[1])
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
    name = "mapgen: on vanilla terrain every city gets a dry, clear mainland site near its planned spot",
    fn = function()
      -- 2.1: game.default_map_gen_settings mixes every planet (oil ocean, lava, ice); use
      -- Nauvis's own
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 314159
      mgs.no_enemies_mode = true
      local s = game.create_surface("tt-mapgen-vanilla", mgs)
      local spacing = 1000
      local prof = helpers.create_profiler()
      local result = remote.call("tt-map", "place_procedural", s.name, 314159, spacing)
      prof.stop()
      log({ "", "mapgen: placing the layout took ", prof }) ---@diagnostic disable-line: assign-type-mismatch
      assert_.equals(#result.missing, 0, "no site for " .. serpent.line(result.missing))
      assert_.equals(#result.placed, #remote.call("tt-map", "layout").cities, "placed")
      local moved = 0
      for i, c in ipairs(result.placed) do
        local x, y = c.x + 0.5, c.y + 0.5
        local area = { { x - 12.5, y - 12.5 }, { x + 12.5, y + 12.5 } }
        assert_.equals(s.count_tiles_filtered({ area = area, collision_mask = "water_tile" }), 0, c.label .. " has water")
        assert_.equals(s.count_entities_filtered({ area = area, type = { "cliff", "tree", "simple-entity" } }), 0,
          c.label .. " has cliffs, trees or rocks")
        local city = s.find_entities_filtered({ name = c.name, position = { x, y }, radius = 1 })
        assert_.equals(#city, 1, c.label .. " not built")
        assert_.truthy(remote.call("tt-map", "mainland", s.name, x, y), c.label .. " on an island")
        -- a site stays near its planned spot, or (no land there) at the same distance from
        -- spawn, turned around it
        local d = math.sqrt((c.x - c.planned.x) ^ 2 + (c.y - c.planned.y) ^ 2)
        local dr = math.abs(math.sqrt(c.x ^ 2 + c.y ^ 2) - math.sqrt(c.planned.x ^ 2 + c.planned.y ^ 2))
        assert_.truthy(d <= 330 or dr <= 330, c.label .. " moved " .. d .. ", " .. dr .. " in distance from spawn")
        moved = math.max(moved, d)
        for j = i + 1, #result.placed do
          local o = result.placed[j]
          local apart = math.sqrt((c.x - o.x) ^ 2 + (c.y - o.y) ^ 2)
          assert_.truthy(apart >= 0.8 * spacing, c.label .. " and " .. o.label .. " " .. apart .. " apart")
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
      local result = remote.call("tt-nauvis", "prepare", s.name, 271828, 1000)
      assert_.equals(#result.missing, 0, "missing " .. serpent.line(result.missing))
      assert_.truthy(s.peaceful_mode, "not peaceful")
      assert_.falsy(game.map_settings.enemy_expansion.enabled, "expansion on")
      assert_.equals(s.count_entities_filtered({ force = "enemy" }), 0, "enemies left")
      for _, r in pairs(s.find_entities_filtered({ area = near, type = "resource" })) do
        local d = math.sqrt(r.position.x ^ 2 + r.position.y ^ 2)
        assert_.truthy(d > clear, r.name .. " " .. math.floor(d) .. " tiles from spawn")
      end
      local outer = s.count_entities_filtered({ area = { { -clear - 120, -clear - 120 }, { clear + 120, clear + 120 } }, type = "resource" })
      local depot
      for _, c in ipairs(result.placed) do if c.name == "tt-city-depot" then depot = c end end
      assert_.truthy(depot and math.sqrt(depot.x ^ 2 + depot.y ^ 2) < 200, "depot not near spawn")
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
    -- 2.8.5
    name = "mapgen: nothing is charted up front; a city's tag appears when its chunk is charted",
    fn = function(ctx)
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 161803
      local s = game.create_surface("tt-mapgen-discover", mgs)
      local result = remote.call("tt-nauvis", "prepare", s.name, 161803, 1000)
      local force = game.forces["player"]
      assert_.equals(#force.find_chart_tags(s), 0, "tags before charting")
      local c = result.placed[#result.placed] -- the last placed: far from spawn
      assert_.falsy(force.is_chunk_charted(s, { math.floor(c.x / 32), math.floor(c.y / 32) }), c.label .. " charted up front")
      force.chart(s, { { c.x - 8, c.y - 8 }, { c.x + 8, c.y + 8 } })
      ctx:wait_until(function() return #force.find_chart_tags(s) > 0 end, 600, function()
        local tags = force.find_chart_tags(s)
        assert_.equals(#tags, 1, "tags after charting one city")
        assert_.equals(tags[1].text, c.label, "tag text")
        assert_.truthy(math.abs(tags[1].position.x - (c.x + 0.5)) < 1 and math.abs(tags[1].position.y - (c.y + 0.5)) < 1, "tag position")
        -- charting it again adds nothing
        force.chart(s, { { c.x - 8, c.y - 8 }, { c.x + 8, c.y + 8 } })
        ctx:wait(60, function()
          assert_.equals(#force.find_chart_tags(s), 1, "tags after charting again")
          game.delete_surface(s)
        end)
      end)
    end,
  },
}
