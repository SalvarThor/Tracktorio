-- 2.8: procedural maps.
local assert_ = require("__tracktorio-tests__/assert")
local city_defs = require("__tracktorio__/shared/city_defs")

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
}
