-- City sizes and port layout (PLAN 2.10). Plain data, read by both stages.
--
-- Cities use the Factorissimo buildings and grow with tier: 8x8, 12x12, 16x16 (the rocket
-- silo keeps the vanilla 9x9). Every item, fluid, construction delivery and service
-- delivery enters or leaves through a port: a spot just outside the wall. Spots follow the
-- Factorissimo art: offsets along each wall from its middle, +-1.5 and +-2.5 on the 8x8,
-- +-2.5 to +-4.5 on the 12x12, +-2.5 to +-5.5 on the 16x16. Only the +-2.5 lines exist at
-- every tier, so tier 1 ports use those (8 spots); a port keeps its line at every tier, and
-- the wall moves 2 tiles out along it when the city grows. Tier 3 smelting's second ports
-- take the +-3.5 lines, which tier 2 adds.
local M = {}

M.TIER_SIZE = { 8, 12, 16 }
M.SILO_SIZE = 9
M.MAX_SIZE = 16

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

--- Tile size of a city at a tier.
---@param def table city definition (shared/city_defs.lua)
---@param tier integer
function M.size(def, tier)
  if def.kind == "silo" then return M.SILO_SIZE end
  return M.TIER_SIZE[tier] or M.TIER_SIZE[#M.TIER_SIZE]
end

--- Items and fluids a tier takes in and gives out: list of { kind, name, flow }.
---@param def table
---@param tier integer
local function flows(def, tier)
  local t = def.tiers[tier]
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
    for _, x in ipairs(t.recipe.ingredients) do add(x.type, x.name, "input") end
    if def.burner and def.burner.fuel then add("item", def.burner.fuel, "input") end
    if def.kind ~= "silo" then -- rocket parts stay in the silo
      for _, x in ipairs(t.recipe.results) do add(x.type, x.name, "output") end
    end
  end
  return out
end

--- All ports of a city across its tiers. Each port:
---   { kind = "item"|"fluid"|"construction"|"service", name = item/fluid name or nil,
---     flow = "input"|"output", wall = "north"|"east"|"south"|"west", offset = number,
---     tiers = { [tier] = true } }
--- Ports are listed inputs first; the order is stable (data and control stage agree).
---@param def table
function M.ports(def)
  local ports, used = {}, {}
  local function key(wall, offset) return wall .. offset end
  local function take(order, wall_hint)
    for _, spot in ipairs(order) do
      if not used[key(spot[1], spot[2])] and (not wall_hint or spot[1] == wall_hint) then
        used[key(spot[1], spot[2])] = true
        return spot[1], spot[2]
      end
    end
    error("tt: no free port spot for city " .. def.name)
  end
  local function find(kind, name, flow)
    for _, p in ipairs(ports) do
      if p.kind == kind and p.name == name and p.flow == flow then return p end
    end
  end
  local function add(kind, name, flow, tier)
    local p = find(kind, name, flow)
    if not p then
      local wall, offset = take(flow == "input" and IN_ORDER or OUT_ORDER)
      p = { kind = kind, name = name, flow = flow, wall = wall, offset = offset, tiers = {} }
      ports[#ports + 1] = p
    end
    p.tiers[tier] = true
  end
  -- inputs, then outputs, across every tier, so a port keeps its spot through upgrades
  for _, flow in ipairs({ "input", "output" }) do
    for tier = 1, #def.tiers do
      for _, f in ipairs(flows(def, tier)) do
        if f.flow == flow then add(f.kind, f.name, f.flow, tier) end
      end
    end
  end
  if def.service then
    for tier = 1, #def.tiers do add("service", M.SERVICE_ITEM, "input", tier) end
  end
  for tier = 1, #def.tiers - 1 do add("construction", nil, "input", tier) end -- tiers with a next tier
  -- Second ports from `def.double_ports_from` on (tier 3 smelting): beside the first, one
  -- line further out from the middle of the wall.
  if def.double_ports_from then
    local doubles = {}
    for _, p in ipairs(ports) do
      if p.kind == "item" then
        local extra = { kind = p.kind, name = p.name, flow = p.flow, wall = p.wall,
          offset = p.offset + (p.offset < 0 and -1 or 1), tiers = {}, second = true }
        for tier = def.double_ports_from, #def.tiers do
          if p.tiers[tier] then extra.tiers[tier] = true end
        end
        if next(extra.tiers) then doubles[#doubles + 1] = extra end
      end
    end
    for _, p in ipairs(doubles) do ports[#ports + 1] = p end
  end
  return ports
end

--- The first port of `kind` ("construction", "service", ...) on a city, or nil.
---@param def table
---@param kind string
function M.find(def, kind)
  for _, p in ipairs(M.ports(def)) do
    if p.kind == kind then return p end
  end
end

--- World position of the hidden chest behind a city's construction or service port, or nil.
--- `by_entity` is shared/city_defs.lua's table (passed in: that module requires this one).
---@param city LuaEntity
---@param kind "construction"|"service"
---@param by_entity table
function M.box_position(city, kind, by_entity)
  local info = by_entity[city.name]
  local p = info and M.find(info.def, kind)
  if not (p and p.tiers[info.tier]) then return nil end
  local spot = M.spot(p, M.size(info.def, info.tier))
  return { x = city.position.x + spot.box[1], y = city.position.y + spot.box[2] }
end

local WALL = {
  north = { 0, -1 }, south = { 0, 1 }, west = { -1, 0 }, east = { 1, 0 },
}

--- Where a port sits on a city of `size` tiles, relative to the city's centre:
--- `outside` is the tile just outside the wall (where the belt or pipe ends), `inside` the
--- building tile behind it (the port's loader), `box` two tiles further in (the hidden
--- chest of a construction or service port, clear of every item port's front tile),
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
