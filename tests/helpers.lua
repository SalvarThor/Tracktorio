-- Shared helpers for test cases.
local port_layout = require("__tracktorio__/shared/port_layout")
local city_defs = require("__tracktorio__/shared/city_defs")

local M = {}

M.surface = function() return game.surfaces[1] end

-- on_string_translated results by request id (the runner fills this in).
M.translations = {}

--- Make a flat, empty test area: land tiles, no entities except characters.
---@param area BoundingBox {{x1,y1},{x2,y2}}
function M.clear_area(area)
  local s = M.surface()
  s.request_to_generate_chunks({ (area[1][1] + area[2][1]) / 2, (area[1][2] + area[2][2]) / 2 }, 4)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = area[1][1], area[2][1] - 1 do
    for y = area[1][2], area[2][2] - 1 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  for _, e in pairs(s.find_entities_filtered({ area = area })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

--- Name of an entity's status, e.g. "working", "full_output".
---@param entity LuaEntity
function M.status_name(entity)
  local status = entity.status
  for k, v in pairs(defines.entity_status) do
    if v == status then return k end
  end
  return tostring(status)
end

---@param name string
---@param position MapPosition
---@param opts table? extra create_entity params
function M.create(name, position, opts)
  local p = { name = name, position = position, force = "player" }
  for k, v in pairs(opts or {}) do p[k] = v end
  return assert(M.surface().create_entity(p), "could not create " .. name)
end

--- Place a city through the mod's remote interface; returns the entity.
function M.place_city(name, position)
  local city = remote.call("tt-city", "place", name, 1, position)
  return assert(city and city.valid and city, "placed city not returned") --[[@as LuaEntity]]
end

--- chest -> burner inserter -> (target). The inserter is fuelled with coal.
--- `pickup` is the chest position; the inserter sits one tile towards the target.
function M.feeder(chest_pos, inserter_pos, direction, contents)
  local chest = M.create("iron-chest", chest_pos)
  for _, stack in ipairs(contents or {}) do chest.insert(stack) end
  local ins = M.create("burner-inserter", inserter_pos, { direction = direction })
  ins.insert({ name = "coal", count = 10 })
  return chest, ins
end

--- Test-only power: an electric-energy-interface producing `watts`, under a substation at
--- `sub_pos` (supply area 18x18). The EEI goes 3 tiles south of the substation. Its buffer
--- holds `buffer_ticks` ticks of production (default 60); use 1 for a hard power cap.
function M.test_power(sub_pos, watts, buffer_ticks)
  watts = watts or 2e6
  local eei = M.create("electric-energy-interface", { sub_pos[1], sub_pos[2] + 3 })
  eei.power_production = watts / 60
  eei.power_usage = 0
  eei.electric_buffer_size = watts / 60 * (buffer_ticks or 60)
  M.create("substation", sub_pos)
  return eei
end

--- The city entity now standing at a position.
---@param position MapPosition
function M.city_at(position)
  for _, e in pairs(M.surface().find_entities_filtered({ position = position, radius = 0.5 })) do
    if string.find(e.name, "^tt%-city%-") then return e end
  end
  return nil
end

--- Tile size of a city prototype.
function M.city_size(name)
  local box = prototypes.entity[name].selection_box
  return math.floor(box.right_bottom.x - box.left_top.x + 0.5)
end

--- Rows and columns just outside a city's walls: { top, bottom, left, right } are the
--- tile-centre coordinates of the first tile outside each wall.
---@param city LuaEntity
function M.edges(city)
  local box = city.bounding_box
  return {
    top = math.floor(box.left_top.y + 0.5) - 0.5, bottom = math.floor(box.right_bottom.y + 0.5) + 0.5,
    left = math.floor(box.left_top.x + 0.5) - 0.5, right = math.floor(box.right_bottom.x + 0.5) + 0.5,
  }
end

--- The tile just outside a city's port for `name` (item or fluid) flowing `flow`, from the
--- mod's port layout (2.10). Returns the position and the direction out of the city.
---@param city LuaEntity
---@param name string
---@param flow "input"|"output"
function M.port_spot(city, name, flow)
  local info = assert(city_defs.by_entity[city.name], "not a city: " .. city.name)
  for _, p in ipairs(port_layout.ports(info.def)) do
    if p.name == name and p.flow == flow then
      local spot = port_layout.spot(p, M.city_size(city.name))
      return { city.position.x + spot.outside[1], city.position.y + spot.outside[2] }, spot.direction
    end
  end
  error("no " .. flow .. " port for " .. name .. " on " .. city.name)
end

--- Every port for `name` flowing `flow`:
--- list of { pos, dir } with `pos` the tile just outside the wall and `dir` out of the city.
--- `name` may also be "service" (2.10.6).
---@param city LuaEntity
---@param name string
---@param flow "input"|"output"
function M.port_spots(city, name, flow)
  local info = assert(city_defs.by_entity[city.name], "not a city: " .. city.name)
  local out = {}
  for _, p in ipairs(port_layout.ports(info.def)) do
    if (p.name == name or p.kind == name) and p.flow == flow then
      local spot = port_layout.spot(p, M.city_size(city.name))
      out[#out + 1] = { pos = { city.position.x + spot.outside[1], city.position.y + spot.outside[2] }, dir = spot.direction }
    end
  end
  return out
end

local STEP = {
  [defines.direction.north] = { 0, -1 }, [defines.direction.south] = { 0, 1 },
  [defines.direction.east] = { 1, 0 }, [defines.direction.west] = { -1, 0 },
}
local BACK = {
  [defines.direction.north] = defines.direction.south, [defines.direction.south] = defines.direction.north,
  [defines.direction.east] = defines.direction.west, [defines.direction.west] = defines.direction.east,
}

--- A slow, exact feed into a city's input port for `name`: two belt tiles towards the
--- port, fed by the test mod's slow loader (3.75 items/s, a quarter of a yellow belt) from
--- an infinity chest.
---@param city LuaEntity
---@param name string
function M.slow_feed_to_port(city, name)
  local s = M.port_spots(city, name, "input")[1]
  local d = STEP[s.dir]
  local toward = BACK[s.dir]
  local function at(k) return { s.pos[1] + d[1] * k, s.pos[2] + d[2] * k } end
  for k = 0, 1 do M.create("transport-belt", at(k), { direction = toward }) end
  M.create("tt-test-slow-loader", at(2), { direction = toward, type = "output" })
  local chest = M.create("infinity-chest", at(3))
  chest.set_infinity_container_filter(1, { name = name, count = 100, mode = "exactly" })
end

--- A belt run on every port for `name`: inputs are fed from an infinity chest, outputs
--- drained into one. Two tiles of `belt` outside the wall, a fast loader (the port
--- prototype), then the chest.
---@param city LuaEntity
---@param name string
---@param flow "input"|"output"
---@param belt string? default "transport-belt"
---@param length integer? tiles of belt, default 2
function M.belt_to_port(city, name, flow, belt, length)
  length = length or 2
  for _, s in ipairs(M.port_spots(city, name, flow)) do
    local d = STEP[s.dir]
    local function at(k) return { s.pos[1] + d[1] * k, s.pos[2] + d[2] * k } end
    local belt_dir = flow == "input" and BACK[s.dir] or s.dir
    for k = 0, length - 1 do M.create(belt or "transport-belt", at(k), { direction = belt_dir }) end
    -- the loader moves items away from the chest on inputs, towards it on outputs
    M.create("tt-belt-port", at(length), { direction = belt_dir, type = flow == "input" and "output" or "input" })
    local chest = M.create("infinity-chest", at(length + 1))
    if flow == "input" and prototypes.item[name] then
      chest.set_infinity_container_filter(1, { name = name, count = 100, mode = "exactly" })
    else
      chest.remove_unfiltered_items = true
    end
  end
end

--- Where the hidden chest behind a city's service port is (2.10.6).
---@param city LuaEntity
---@param kind "service"
function M.box_spot(city, kind)
  return port_layout.box_position(city, kind, city_defs.by_entity)
end

--- An infinity pipe at a city's fluid port: a supply (`fill` true) or a drain.
---@param city LuaEntity
---@param fluid string
---@param flow "input"|"output"
---@param fill boolean?
function M.pipe_at(city, fluid, flow, fill)
  local pos = M.port_spot(city, fluid, flow)
  local p = M.create("infinity-pipe", pos)
  p.set_infinity_pipe_filter(fill and { name = fluid, percentage = 1, mode = "exactly" }
    or { name = fluid, percentage = 0, mode = "exactly" })
  return p
end

--- A chest of `stack` feeding a belt into the city's port for that item (2.10.10): chest
--- -> fast loader -> 2 belts -> port. Returns the chest.
---@param city LuaEntity
---@param stack ItemStackDefinition
function M.belt_in(city, stack)
  local s = assert(M.port_spots(city, stack.name, "input")[1], "no input port for " .. stack.name .. " on " .. city.name)
  local d, back = STEP[s.dir], BACK[s.dir]
  local function at(k) return { s.pos[1] + d[1] * k, s.pos[2] + d[2] * k } end
  M.create("transport-belt", at(0), { direction = back })
  M.create("transport-belt", at(1), { direction = back })
  M.create("tt-belt-port", at(2), { direction = back, type = "output" })
  local chest = M.create("steel-chest", at(3))
  chest.insert(stack)
  return chest
end

--- The city's output port for `item` -> 2 belts -> fast loader -> chest. Returns the chest.
---@param city LuaEntity
---@param item string
function M.belt_out(city, item)
  local s = assert(M.port_spots(city, item, "output")[1], "no output port for " .. item .. " on " .. city.name)
  local d = STEP[s.dir]
  local function at(k) return { s.pos[1] + d[1] * k, s.pos[2] + d[2] * k } end
  M.create("transport-belt", at(0), { direction = s.dir })
  M.create("transport-belt", at(1), { direction = s.dir })
  M.create("tt-belt-port", at(2), { direction = s.dir, type = "input" })
  return M.create("steel-chest", at(3))
end

--- Clear an area and build a city at {x + 0.5, 0.5} with its inputs delivered by belt into
--- its ports (one chest per item) and, with `with_output`, its item products belted out
--- into one chest (2.10.10). The MVP goal box has no ports: it keeps input chest ->
--- inserter -> box. Returns city, the first input chest, the output chest (or nil).
---@param name string city entity name
---@param x number
---@param contents ItemStackDefinition[] what to deliver
---@param with_output boolean
function M.city_rig(name, x, contents, with_output)
  local half = M.city_size(name) / 2
  M.clear_area({ { x - half - 7, -half - 7 }, { x + half + 8, half + 8 } })
  local city = M.place_city(name, { x + 0.5, 0.5 })
  local e = M.edges(city)
  if not city_defs.by_entity[name] then -- the goal box
    local cin = M.feeder({ x + 0.5, e.top - 1 }, { x + 0.5, e.top }, defines.direction.north, contents)
    return city, cin, nil
  end
  local first
  for _, stack in ipairs(contents) do
    local chest = M.belt_in(city, stack)
    first = first or chest
  end
  local cout
  if with_output then
    local info = city_defs.by_entity[name]
    for _, p in ipairs(port_layout.ports(info.def)) do
      if p.kind == "item" and p.flow == "output" and not cout then
        cout = M.belt_out(city, p.name)
      end
    end
  end
  return city, first, cout
end

return M
