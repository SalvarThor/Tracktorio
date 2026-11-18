-- Shared helpers for test cases.
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

--- Construction port of a city (nil if none).
---@param city LuaEntity
function M.port_of(city)
  local s = remote.call("tt-city", "upgrade_status", city)
  return s and s.port
end

--- Put `count` of `item` into a city's port in chunks, counting after each chunk (as the
--- once-a-second port tick would). Returns what could not be inserted. If the city upgrades
--- along the way, the rest is refused by the new port's filters and returned.
---@param city LuaEntity
---@param item string
---@param count integer
function M.feed_port(city, item, count)
  local port = assert(M.port_of(city), "no port")
  local inv = assert(port.get_inventory(defines.inventory.chest))
  while count > 0 and port.valid do
    local n = inv.insert({ name = item, count = count })
    if n == 0 then return count end
    count = count - n
    remote.call("tt-city", "port_tick")
  end
  return count
end

--- The city entity now standing at a position (after an upgrade replaced it).
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

--- Clear an area and build: input chest -> inserter -> city -> inserter -> output chest.
--- The city is centred at {x + 0.5, 0.5}. Returns city, input chest, output chest (or nil).
---@param name string city entity name
---@param x number
---@param contents ItemStackDefinition[] input chest contents
---@param with_output boolean
function M.city_rig(name, x, contents, with_output)
  local size = M.city_size(name)
  local half = size / 2
  local top, bottom = 0.5 - half, 0.5 + half
  M.clear_area({ { x - half - 4, top - 4 }, { x + half + 5, bottom + 5 } })
  local city = M.place_city(name, { x + 0.5, 0.5 })
  local N = defines.direction.north
  local cin = M.feeder({ x + 0.5, top - 1.5 }, { x + 0.5, top - 0.5 }, N, contents)
  local cout
  if with_output then cout = M.feeder({ x + 0.5, bottom + 1.5 }, { x + 0.5, bottom + 0.5 }, N, {}) end
  return city, cin, cout
end

return M
