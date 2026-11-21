-- City size and port layout (PLAN 2.10, 2.15). Plain data, read by both stages.
--
-- Every city is a 12x12 Factorissimo building (2.15; the rocket silo keeps the vanilla 9x9).
-- Every item, fluid and service delivery enters or leaves through a port: a spot just
-- outside the wall. Spots follow the Factorissimo art: offsets +-2.5 along each wall from
-- its middle (8 spots).
local M = {}

M.SIZE = 12
M.SILO_SIZE = 9
M.MAX_SIZE = 12

-- First choices for inputs and for outputs. Each is { wall, offset }; a port takes the
-- first spot not yet used.
local IN_ORDER = {
  { "north", -2.5 }, { "north", 2.5 }, { "west", -2.5 }, { "west", 2.5 },
  { "east", -2.5 }, { "east", 2.5 }, { "south", -2.5 }, { "south", 2.5 },
}
local OUT_ORDER = {
  { "south", -2.5 }, { "south", 2.5 }, { "east", 2.5 }, { "east", -2.5 },
  { "west", 2.5 }, { "west", -2.5 }, { "north", 2.5 }, { "north", -2.5 },
}

M.SERVICE_ITEM = "repair-pack"

--- Tile size of a city.
---@param def table city definition (shared/city_defs.lua)
function M.size(def)
  return def.kind == "silo" and M.SILO_SIZE or M.SIZE
end

--- Items and fluids a city takes in and gives out: list of { kind, name, flow }.
---@param def table
local function flows(def)
  local out = {}
  local linked = {} -- fluids on a hidden link (steam to the power cities' generators)
  for _, box in ipairs(def.fluid_boxes or {}) do
    if box.linked_id then linked[box.filter] = true end
  end
  local function add(kind, name, flow)
    if kind == "fluid" and linked[name] then return end
    for _, f in ipairs(out) do
      if f.kind == kind and f.name == name and f.flow == flow then return end
    end
    out[#out + 1] = { kind = kind, name = name, flow = flow }
  end
  if def.kind == "lab" then
    for _, pack in ipairs(def.inputs) do add("item", pack, "input") end
  else
    for _, x in ipairs(def.recipe.ingredients) do add(x.type, x.name, "input") end
    if def.burner and def.burner.fuel then add("item", def.burner.fuel, "input") end
    if def.kind ~= "silo" then -- rocket parts stay in the silo
      for _, x in ipairs(def.recipe.results) do add(x.type, x.name, "output") end
    end
  end
  return out
end

--- All ports of a city. Each port:
---   { kind = "item"|"fluid"|"service", name = item/fluid name or nil,
---     flow = "input"|"output", wall = "north"|"east"|"south"|"west", offset = number }
--- Ports are listed inputs first; the order is stable (data and control stage agree).
---@param def table
function M.ports(def)
  local ports, used = {}, {}
  local function key(wall, offset) return wall .. offset end
  local function take(order)
    for _, spot in ipairs(order) do
      if not used[key(spot[1], spot[2])] then
        used[key(spot[1], spot[2])] = true
        return spot[1], spot[2]
      end
    end
    error("tt: no free port spot for city " .. def.name)
  end
  local function add(kind, name, flow)
    local wall, offset = take(flow == "input" and IN_ORDER or OUT_ORDER)
    ports[#ports + 1] = { kind = kind, name = name, flow = flow, wall = wall, offset = offset }
  end
  local all = flows(def)
  for _, flow in ipairs({ "input", "output" }) do
    for _, f in ipairs(all) do
      if f.flow == flow then add(f.kind, f.name, f.flow) end
    end
  end
  if def.service then add("service", M.SERVICE_ITEM, "input") end
  return ports
end

--- The first port of `kind` ("service", ...) on a city, or nil.
---@param def table
---@param kind string
function M.find(def, kind)
  for _, p in ipairs(M.ports(def)) do
    if p.kind == kind then return p end
  end
end

--- World position of the hidden chest behind a city's service port, or nil.
--- `by_entity` is shared/city_defs.lua's table (passed in: that module requires this one).
---@param city LuaEntity
---@param kind "service"
---@param by_entity table
function M.box_position(city, kind, by_entity)
  local info = by_entity[city.name]
  local p = info and M.find(info.def, kind)
  if not p then return nil end
  local spot = M.spot(p, M.size(info.def))
  return { x = city.position.x + spot.box[1], y = city.position.y + spot.box[2] }
end

local WALL = {
  north = { 0, -1 }, south = { 0, 1 }, west = { -1, 0 }, east = { 1, 0 },
}

--- Where a port sits on a city of `size` tiles, relative to the city's centre:
--- `outside` is the tile just outside the wall (where the belt or pipe ends), `inside` the
--- building tile behind it (the port's loader), `box` two tiles further in (the hidden
--- chest of a service port, clear of every item port's front tile),
--- `direction` points out of the building.
---@param port table
---@param size integer
function M.spot(port, size)
  local half = size / 2
  local offset = port.offset
  if size % 2 == 1 then offset = offset - (offset < 0 and -0.5 or 0.5) end -- odd sizes: tile centres on whole numbers
  local w = WALL[port.wall]
  local function at(depth) -- depth: distance from the centre across the wall
    if w[1] == 0 then return { offset, w[2] * depth } end
    return { w[1] * depth, offset }
  end
  return {
    outside = at(half + 0.5),
    inside = at(half - 0.5),
    box = at(half - 2.5),
    direction = defines.direction[port.wall],
  }
end

return M
