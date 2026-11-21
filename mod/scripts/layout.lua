-- Procedural plot layout (PLAN 2.15.6; before that, of the cities themselves, 2.8.2). Pure
-- planning: positions only, nothing is placed here. Seeded, so the same map seed always
-- gives the same layout.
-- User decisions (2026-11-21, phase 2.15): one plot per site, sites at least SPACING apart
-- (x the "City spacing" startup setting); about TARGET_PLOTS plots; a starter site of 2
-- near spawn for the first power and water cities (playtest 2.15.10: bigger sites let
-- cities trade by short belts). Any city on any plot. Sites take no account of resources.

local M = {}

-- Minimum tiles between two sites at "City spacing" 1.
M.SPACING = 300
-- Each site's own elbow room, in spacings: 1 + GAP_SPREAD * random^GAP_SKEW (skewed to the
-- low end: 1x..2x, mean ~1.3x). Two sites stay at least the larger of their two gaps apart,
-- so some sit at the minimum and others alone in open country (user, playtest 2.8.12:
-- "the variance a lot higher").
M.GAP_SPREAD, M.GAP_SKEW = 1, 2.5
M.TARGET_PLOTS = 75
M.STARTER_PLOTS = 2
M.STARTER_RADIUS = { 40, 80 } -- the starter site's distance from spawn
M.MAX_PLOTS = 1 -- an ordinary site has 1..MAX_PLOTS plots
M.TRIES = 30 -- random angles per radius before stepping out
M.STEP_OUT = 1.08
M.FIRST_RING = 1.2 -- the first ordinary sites plan this many spacings out

-- Plots of a site (the starter's two side by side; up to a 2 x 2 grid), PITCH tiles from plot centre to plot centre (a
-- 12-tile plot and GAP tiles of ground between: room for a belt run or a rail).
M.GAP = 10
M.PITCH = 12 + M.GAP
M.SITE_HALF = M.PITCH / 2 + 6 -- half the side of a full 2 x 2 site (17)

--- Half the side of a site of `n` plots (a single plot: 6).
---@param n integer
function M.site_half(n)
  return n == 1 and 6 or M.SITE_HALF
end

--- Minimum distance between sites for this game: SPACING x the startup setting.
function M.spacing()
  local s = settings.startup["tt-city-spacing"]
  return M.SPACING * (s and s.value --[[@as number]] or 1)
end

--- LuaRandomGenerator treats seeds below 341 alike (2.1.24: seeds 7 and 8 gave the same
--- layout), so spread the map seed first. seed * 40503 stays below 2^53, so this is exact.
---@param seed integer
function M.mix_seed(seed)
  local h = ((seed % 4294967296) * 40503 + 12345) % 4294967296
  if h < 341 then h = h + 341 end
  return h
end

--- Plot centres of a site of `n` plots, relative to the site's centre (a tile corner):
--- 1 in the middle, 2 side by side, 3 in an L, 4 in a square.
---@param n integer
---@return number[][]
function M.offsets(n)
  local h = M.PITCH / 2
  if n == 1 then return { { 0, 0 } } end
  if n == 2 then return { { -h, 0 }, { h, 0 } } end
  local square = { { -h, -h }, { h, -h }, { -h, h }, { h, h } }
  if n == 3 then return { square[1], square[2], square[3] } end
  return square
end

--- Plan the layout: a list of sites { x, y (integers, spawn at 0, 0), plots = n, starter =
--- true? }, nearest spawn first; plots add up to at least TARGET_PLOTS.
---@param seed integer
---@param spacing number minimum distance between two sites
---@return table[]
function M.plan(seed, spacing)
  local rng = game.create_random_generator(M.mix_seed(seed))
  local placed = {}
  local function clear(x, y, gap)
    for _, p in ipairs(placed) do
      local need = math.max(gap, p.gap)
      if (p.x - x) ^ 2 + (p.y - y) ^ 2 < need * need then return false end
    end
    return true
  end
  -- the starter site, close to spawn
  local a = rng() * 2 * math.pi
  local r0 = M.STARTER_RADIUS[1] + rng() * (M.STARTER_RADIUS[2] - M.STARTER_RADIUS[1])
  placed[1] = { x = math.floor(r0 * math.cos(a)), y = math.floor(r0 * math.sin(a)), plots = M.STARTER_PLOTS,
    starter = true, gap = spacing }
  local total = M.STARTER_PLOTS
  local r = spacing * M.FIRST_RING
  while total < M.TARGET_PLOTS do
    local gap = spacing * (1 + M.GAP_SPREAD * rng() ^ M.GAP_SKEW)
    local done = false
    for _ = 1, M.TRIES do
      local ang = rng() * 2 * math.pi
      local rr = r * (0.9 + 0.2 * rng())
      local x, y = math.floor(rr * math.cos(ang)), math.floor(rr * math.sin(ang))
      if clear(x, y, gap) then
        local n = 1 + math.floor(rng() * M.MAX_PLOTS)
        placed[#placed + 1] = { x = x, y = y, plots = n, gap = gap }
        total = total + n
        done = true
        break
      end
    end
    if not done then r = r * M.STEP_OUT end
  end
  for _, p in ipairs(placed) do p.gap = nil end
  return placed
end

return M
