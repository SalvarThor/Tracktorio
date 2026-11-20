-- City sites on real terrain (PLAN 2.8.3). A planned spot (scripts/layout.lua) moves to
-- the nearest land that fits the city and a margin, not an island. Trees, rocks, cliffs
-- and decoratives there are cleared.
-- Cheap by design (probe, 2.1.24): water is read from the map generator's "elevation"
-- property (below 0 is water on Nauvis), which needs no chunk generation: 10,000 points
-- cost ~9 ms, a chunk ~3 ms. Positions in chunks that already exist use the real tile,
-- so script-set tiles count. A planned spot that is fine is checked directly; otherwise one
-- batched grid covers the whole search. Only the chunks under the chosen site are
-- generated, and its real tiles are checked again. 26 cities: ~3.4 s.
local M = {}

M.HALF = 4.5 -- a city is 9 x 9
M.MARGIN = 8 -- room around it for the construction and service ports and the first rails
M.STEP = 8 -- spacing of candidate spots on the search spiral
M.SEARCH = 320 -- furthest a site moves from its planned spot
M.SAMPLE = 3 -- sample spacing of the dry check over the box
M.LAND_ABOVE = 1 -- elevation counted as land (a little above the shoreline)
M.RAYS, M.RAY_LENGTH, M.RAY_STEP = 16, 96, 4
M.RAYS_NEEDED = 6 -- rays that must reach RAY_LENGTH over land (an island fails nearly all)

--- For each position, is it water? Generated chunks: the real tile. Elsewhere: elevation.
---@param surface LuaSurface
---@param positions number[][]
---@return boolean[]
local function water(surface, positions)
  local out, ask, idx = {}, {}, {}
  for i, p in ipairs(positions) do
    local x, y = p[1], p[2]
    if surface.is_chunk_generated({ math.floor(x / 32), math.floor(y / 32) }) then
      local tile = surface.get_tile(x, y)
      out[i] = tile.collides_with("water_tile") or tile.name == "out-of-map"
    else
      ask[#ask + 1] = p
      idx[#ask] = i
    end
  end
  if #ask > 0 then
    local ok, props = pcall(surface.calculate_tile_properties, { "elevation" }, ask)
    for j, i in pairs(idx) do
      -- no elevation property (a map generator without one): assume land, the real
      -- tiles are checked once the site's chunks exist
      out[i] = ok and props.elevation and props.elevation[j] < M.LAND_ABOVE or false
    end
  end
  return out
end

local function any(list)
  for _, v in ipairs(list) do if v then return true end end
  return false
end

--- Points over the city's box (city and margin) around a centre.
local function box_points(x, y)
  local r, pts = M.HALF + M.MARGIN, {}
  for dx = -r, r, M.SAMPLE do
    for dy = -r, r, M.SAMPLE do pts[#pts + 1] = { x + dx, y + dy } end
  end
  return pts
end

--- Is the spot on the mainland? Most rays out of it must stay on land to RAY_LENGTH
--- (an island fails nearly every ray; a lake shore fails a few).
---@param surface LuaSurface
---@param x number
---@param y number
function M.mainland(surface, x, y)
  local pts, per = {}, math.floor(M.RAY_LENGTH / M.RAY_STEP)
  for i = 0, M.RAYS - 1 do
    local a = i * 2 * math.pi / M.RAYS
    for d = 1, per do pts[#pts + 1] = { x + math.cos(a) * d * M.RAY_STEP, y + math.sin(a) * d * M.RAY_STEP } end
  end
  local wet = water(surface, pts)
  local ok = 0
  for i = 0, M.RAYS - 1 do
    local clear = true
    for d = 1, per do
      if wet[i * per + d] then clear = false; break end
    end
    if clear then ok = ok + 1 end
  end
  return ok >= M.RAYS_NEEDED
end

---@param surface LuaSurface
local function usable(surface, x, y)
  return not any(water(surface, box_points(x, y))) and M.mainland(surface, x, y)
end

--- Generate the chunks under a site's box.
---@param surface LuaSurface
local function generate(surface, x, y)
  local r = M.HALF + M.MARGIN
  for cx = math.floor((x - r) / 32), math.floor((x + r) / 32) do
    for cy = math.floor((y - r) / 32), math.floor((y + r) / 32) do
      surface.request_to_generate_chunks({ cx * 32 + 16, cy * 32 + 16 }, 0)
    end
  end
  surface.force_generate_chunk_requests()
end

--- Water forecast over a square around (x, y), one point per RAY_STEP tiles, read in one
--- batch. Returns wet(px, py) for any point in the square.
---@param surface LuaSurface
local function grid(surface, x, y, radius)
  local g = M.RAY_STEP
  local n = math.ceil(radius / g)
  local pts = {}
  for i = -n, n do
    for j = -n, n do pts[#pts + 1] = { x + i * g, y + j * g } end
  end
  local wet = water(surface, pts)
  local side = 2 * n + 1
  return function(px, py)
    local i = math.floor((px - x) / g + 0.5)
    local j = math.floor((py - y) / g + 0.5)
    if i < -n or i > n or j < -n or j > n then return true end
    return wet[(i + n) * side + (j + n) + 1]
  end
end

--- Candidate check against the grid: the box is dry and enough rays reach land's end.
local function usable_on(wet, x, y)
  local r, g = M.HALF + M.MARGIN, M.RAY_STEP
  for dx = -r, r + g - 1, g do
    for dy = -r, r + g - 1, g do
      if wet(x + math.min(dx, r), y + math.min(dy, r)) then return false end
    end
  end
  local ok = 0
  for i = 0, M.RAYS - 1 do
    local a = i * 2 * math.pi / M.RAYS
    local ca, sa = math.cos(a), math.sin(a)
    local clear = true
    for d = g, M.RAY_LENGTH, g do
      if wet(x + ca * d, y + sa * d) then clear = false; break end
    end
    if clear then
      ok = ok + 1
      if ok >= M.RAYS_NEEDED then return true end
    end
  end
  return false
end

--- The real check once the site's chunks exist: real tiles in the box, then mainland.
---@param surface LuaSurface
local function confirmed(surface, x, y)
  local r = M.HALF + M.MARGIN
  local area = { { x - r, y - r }, { x + r, y + r } }
  if surface.count_tiles_filtered({ area = area, collision_mask = "water_tile", limit = 1 }) > 0 then return false end
  if surface.count_tiles_filtered({ area = area, name = "out-of-map", limit = 1 }) > 0 then return false end
  return M.mainland(surface, x, y)
end

--- Nearest usable spot to (x, y): integer tile coordinates of the city's centre tile, or
--- nil if none within SEARCH. `taken` lists sites already chosen (x, y), which a site
--- keeps `apart` from. The chunks under the returned site are generated.
---@param surface LuaSurface
---@param x integer
---@param y integer
---@param taken table[]?
---@param apart number?
function M.find(surface, x, y, taken, apart)
  local function free(cx, cy)
    for _, t in ipairs(taken or {}) do
      if (t.x - cx) ^ 2 + (t.y - cy) ^ 2 < (apart or 0) ^ 2 then return false end
    end
    return true
  end
  local function try(cx, cy)
    generate(surface, cx + 0.5, cy + 0.5)
    return confirmed(surface, cx + 0.5, cy + 0.5)
  end
  -- most planned spots are fine as they are: check that before building the grid
  if free(x, y) and usable(surface, x + 0.5, y + 0.5) and try(x, y) then return { x = x, y = y } end
  local wet = grid(surface, x + 0.5, y + 0.5, M.SEARCH + M.RAY_LENGTH + M.HALF + M.MARGIN + M.RAY_STEP)
  for ring = 1, math.floor(M.SEARCH / M.STEP) do
    local r = ring * M.STEP
    local n = ring * 6
    for i = 0, n - 1 do
      local a = i * 2 * math.pi / n
      local cx, cy = math.floor(x + r * math.cos(a)), math.floor(y + r * math.sin(a))
      -- the grid is a forecast: confirm on the real tiles
      if free(cx, cy) and usable_on(wet, cx + 0.5, cy + 0.5) and try(cx, cy) then return { x = cx, y = cy } end
    end
  end
  return nil
end
--- Clear trees, rocks, cliffs and decoratives from the city's box around the centre tile.
---@param surface LuaSurface
---@param x integer
---@param y integer
function M.clear(surface, x, y)
  local r = M.HALF + M.MARGIN
  local area = { { x + 0.5 - r, y + 0.5 - r }, { x + 0.5 + r, y + 0.5 + r } }
  for _, e in pairs(surface.find_entities_filtered({ area = area, type = { "tree", "simple-entity", "cliff", "fish" } })) do
    e.destroy()
  end
  -- biters are off (2.8.4), but a map made with them must not block a city
  for _, e in pairs(surface.find_entities_filtered({ area = area, force = "enemy" })) do e.destroy() end
  surface.destroy_decoratives({ area = area })
end

return M
