-- Procedural city layout (PLAN 2.8.2). Pure planning: positions only, nothing is placed
-- here. Seeded, so the same map seed always gives the same layout.
-- User decisions (DECISIONS.md, 2026-11-20): cities at least SPACING apart; deeper cities in
-- the production chain more likely far from spawn, but at random; the coal fuel depot near
-- spawn; cities take no account of resources.
local config = require("shared.config")
local city_defs = require("shared.city_defs")

local M = {}

M.SPACING = 1000 -- tiles between any two cities at "City spacing" 1
M.DEPOT_RADIUS = { 40, 80 } -- the coal fuel depot's distance from spawn
-- Distance from spawn, in spacings: MIN_R + SPREAD * (DEPTH_WEIGHT * depth share +
-- (1 - DEPTH_WEIGHT) * random). Crowding pushes a city further out.
M.MIN_R, M.SPREAD, M.DEPTH_WEIGHT = 1, 2.5, 0.5
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
  for _, c in ipairs(cities) do
    local e = {}
    for k, v in pairs(c) do e[k] = v end
    e.depth = depth_of(c.name)
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
  local function clear(x, y)
    for _, p in ipairs(placed) do
      if (p.x - x) ^ 2 + (p.y - y) ^ 2 < spacing * spacing then return false end
    end
    return true
  end
  for _, e in ipairs(todo) do
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
        if clear(x, y) then
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
