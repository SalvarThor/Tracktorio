-- 2.9: the water city, the only source of water.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local WATER = "tt-city-water"
local X = 24000

local function info(city) return remote.call("tt-city", "info", city) end

--- An infinity pipe at `pos` keeping `fluid` empty (a drain).
local function drain(pos, fluid)
  local p = h.create("infinity-pipe", pos)
  p.set_infinity_pipe_filter({ name = fluid, percentage = 0, mode = "exactly" })
  return p
end

--- A water city centred at (x + 0.5, 0.5), nothing else around it.
local function place(x)
  h.clear_area({ { x - 14, -14 }, { x + 14, 14 } })
  return h.place_city(WATER, { x + 0.5, 0.5 })
end

return {
  {
    -- 2.9.1
    name = "water: 600 / 1,200 / 2,400 water/s at tiers 1-3, no ingredients, no power",
    fn = function()
      for tier, want in ipairs({ 600, 1200, 2400 }) do
        local name = tier == 1 and WATER or (WATER .. "-t" .. tier)
        local p = assert(prototypes.entity[name], name)
        local r = p.fixed_recipe
        assert_.equals(#r.ingredients, 0, name .. " ingredients")
        local per_s = p.get_crafting_speed() / r.energy
        assert_.equals(r.products[1].name, "water", name .. " product")
        assert_.equals(r.products[1].amount * per_s, want, name .. " water/s")
        assert_.falsy(p.electric_energy_source_prototype, name .. " draws power")
      end
    end,
  },
  {
    name = "water: with nothing but a pipe out of it, a water city makes 600 water/s",
    fn = function(ctx)
      local city = place(X)
      drain({ X + 0.5, 5.5 }, "water")
      ctx:wait(60, function() -- settle
        local start = city.products_finished
        ctx:wait(600, function()
          local crafts = city.products_finished - start
          assert_.truthy(crafts >= 9 and crafts <= 11, "crafts in 10 s: " .. crafts)
          assert_.equals(info(city).status, "running")
        end)
      end)
    end,
  },
  {
    name = "water: undrained, it fills up and says output full (backpressure)",
    fn = function(ctx)
      local city = place(X + 60)
      ctx:wait_until(function() return info(city).status == "output_full" end, 60 * 30, function()
        local made = city.products_finished
        ctx:wait(120, function()
          assert_.equals(city.products_finished, made, "kept making water while full")
        end)
      end)
    end,
  },
  {
    -- 2.9.3
    name = "water: a shore site goes to a real lake, not a puddle nearer the planned spot",
    fn = function()
      local s = h.surface()
      local cx, cy = X + 400, 0
      local R = 230
      s.request_to_generate_chunks({ cx, cy }, math.ceil(R / 32) + 1)
      s.force_generate_chunk_requests()
      h.clear_area({ { cx - R, cy - R }, { cx + R, cy + R } })
      local tiles = {}
      for x = cx - R, cx + R - 1 do
        for y = cy - R, cy + R - 1 do
          local lake = (x + 0.5 - (cx + 80)) ^ 2 + (y + 0.5 - cy) ^ 2 <= 18 * 18
          local puddle = math.abs(x - (cx + 20)) <= 1 and math.abs(y - cy) <= 1
          tiles[#tiles + 1] = { name = (lake or puddle) and "water" or "grass-1", position = { x, y } }
        end
      end
      s.set_tiles(tiles)
      local site = remote.call("tt-map", "find_shore", s.name, cx, cy, 120)
      assert(site, "no shore site")
      local d = math.sqrt((site.x + 0.5 - (cx + 80)) ^ 2 + (site.y + 0.5 - cy) ^ 2)
      assert_.truthy(d > 18 + 12 and d < 18 + 30, "site " .. d .. " from the lake centre")
    end,
  },
  {
    name = "water: on Nauvis terrain a shore site is dry, with a lake at its edge",
    fn = function()
      local mgs = game.surfaces["nauvis"].map_gen_settings
      mgs.seed = 314159
      local s = game.create_surface("tt-water-shore", mgs)
      local found = 0
      for _, spot in ipairs({ { 0, 600 }, { -900, -300 }, { 1200, 400 } }) do
        local site = remote.call("tt-map", "find_shore", s.name, spot[1], spot[2])
        if site then
          found = found + 1
          local x, y = site.x + 0.5, site.y + 0.5
          assert_.equals(s.count_tiles_filtered({ area = { { x - 12.5, y - 12.5 }, { x + 12.5, y + 12.5 } }, collision_mask = "water_tile" }), 0, "water on the site")
          assert_.truthy(s.count_tiles_filtered({ area = { { x - 24.5, y - 24.5 }, { x + 24.5, y + 24.5 } }, collision_mask = "water_tile" }) > 0, "no water at the edge")
          assert_.truthy(s.count_tiles_filtered({ position = { x, y }, radius = 40, collision_mask = "water_tile" }) >= 600, "lake too small")
          log("water: shore site for " .. serpent.line(spot) .. " at " .. site.x .. "," .. site.y)
        end
      end
      assert_.equals(found, 3, "shore sites found")
      game.delete_surface(s)
    end,
  },
  {
    name = "water: plates delivered to its port upgrade it to tier 2 (1,200/s)",
    fn = function()
      local city = place(X + 120)
      local pos = city.position
      h.feed_port(city, "iron-plate", 1000)
      h.feed_port(city, "copper-plate", 1000)
      local now = assert(h.city_at(pos))
      assert_.equals(now.name, WATER .. "-t2")
    end,
  },
}
