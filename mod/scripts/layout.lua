-- Procedural city layout (PLAN 2.8.2). Pure planning: positions only, nothing is placed
-- here. Seeded, so the same map seed always gives the same layout.
-- User decisions (DECISIONS.md, 2026-11-20): cities at least SPACING apart; deeper cities in
-- the production chain more likely far from spawn, but at random; the coal fuel depot near
-- spawn; cities take no account of resources.
local config = require("shared.config")
local city_defs = require("shared.city_defs")

local M = {}

-- Minimum tiles between any two cities at "City spacing" 1. Playtests: 1000 "a bit much",
-- 500 "too tight" with every city alike, 750 "too uniform". Since 2.8.12 the minimum is
-- 500 and the spread comes from GAP (user: "as low as 500 but the variance a lot higher").
M.SPACING = 500
-- Each city's own elbow room, in spacings: 1 + GAP_SPREAD * random^GAP_SKEW (skewed to the
-- low end: 1x..4x, mean ~1.75x). Two cities stay at least the larger of their two gaps
-- apart, so some sit 500 tiles from a neighbour and others alone in open country.
M.GAP_SPREAD, M.GAP_SKEW = 3, 2.5
M.DEPOT_RADIUS = { 40, 80 } -- the coal fuel depot's distance from spawn
-- Distance from spawn, in spacings: MIN_R + SPREAD * (DEPTH_WEIGHT * depth share +
-- (1 - DEPTH_WEIGHT) * random). Crowding pushes a city further out.
M.MIN_R, M.SPREAD, M.DEPTH_WEIGHT = 1.5, 5, 0.4
M.TRIES = 30 -- random angles per radius before stepping out
M.STEP_OUT = 1.1

--- Minimum distance between cities for this game: SPACING x the startup setting.
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

local function depth_of(entity_name)
  local info = city_defs.by_entity[entity_name]
  return info and city_defs.depth[info.def.name] or 1
end

--- Plan the layout. `cities` is a list of { name = entity name, ... } (map.CITIES); the
--- result is a copy of each entry with x, y (integers, spawn at 0, 0) and depth.
---@param cities table[]
---@param seed integer
---@param spacing number minimum distance between any two cities
---@return table[]
function M.plan(cities, seed, spacing)
  local rng = game.create_random_generator(M.mix_seed(seed))
  local max_depth = 1
  local todo = {}
  -- Several cities of one type (the coal power cities): only the first plans at its own
  -- depth; each further copy plans one deeper, so they spread outward instead of all
  -- landing near spawn (playtest 2.8.7).
  local copies = {}
  for _, c in ipairs(cities) do
    local e = {}
    for k, v in pairs(c) do e[k] = v end
    e.copy = copies[c.name] or 0
    copies[c.name] = e.copy + 1
    e.depth = depth_of(c.name) + e.copy
    e.order = rng()
    max_depth = math.max(max_depth, e.depth)
    todo[#todo + 1] = e
  end
  -- the depot first, then shallow before deep (ties in random order)
  table.sort(todo, function(a, b)
    local da, db = a.name == config.CITY.depot, b.name == config.CITY.depot
    if da ~= db then return da end
    if a.depth ~= b.depth then return a.depth < b.depth end
    return a.order < b.order
  end)

  local placed = {}
  local function clear(x, y, gap)
    for _, p in ipairs(placed) do
      local need = math.max(gap, p.gap)
      if (p.x - x) ^ 2 + (p.y - y) ^ 2 < need * need then return false end
    end
    return true
  end
  for _, e in ipairs(todo) do
    -- (the depot by spawn keeps only the minimum, or it would push the early game away)
    e.gap = e.name == config.CITY.depot and spacing or spacing * (1 + M.GAP_SPREAD * rng() ^ M.GAP_SKEW)
    local r
    if e.name == config.CITY.depot then
      r = M.DEPOT_RADIUS[1] + rng() * (M.DEPOT_RADIUS[2] - M.DEPOT_RADIUS[1])
    else
      local share = max_depth > 1 and (e.depth - 1) / (max_depth - 1) or 0
      r = spacing * (M.MIN_R + M.SPREAD * (M.DEPTH_WEIGHT * share + (1 - M.DEPTH_WEIGHT) * rng()))
    end
    while true do
      local done = false
      for _ = 1, M.TRIES do
        local a = rng() * 2 * math.pi
        local rr = r * (0.9 + 0.2 * rng())
        local x, y = math.floor(rr * math.cos(a)), math.floor(rr * math.sin(a))
        if clear(x, y, e.gap) then
          e.x, e.y = x, y
          done = true
          break
        end
      end
      if done then break end
      r = r * M.STEP_OUT
    end
    e.order = nil
    placed[#placed + 1] = e
  end
  return placed
end

return M
