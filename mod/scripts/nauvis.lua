-- New Game on Nauvis (PLAN 2.8.4). Started from the New Game screen (the freeplay
-- scenario), the mod plays on Nauvis with its vanilla terrain and resources. Its own
-- scenario keeps the fixed, hand-made map (scripts/map.lua).
-- User decisions (DECISIONS.md, 2026-11-20): biters forced off, whatever the map settings;
-- no resources near spawn; cities laid out by scripts/layout.lua and scripts/sites.lua.
local map = require("scripts.map")
local start_kit = require("scripts.start_kit")
local layout = require("scripts.layout")

local M = {}

M.START_CLEAR = 300 -- no resources within this many tiles of spawn (tuning)

--- Is this game the freeplay scenario (New Game)? Freeplay registers its remote interface
--- when its control.lua loads, before any on_init.
function M.is_freeplay()
  return remote.interfaces["freeplay"] ~= nil
end

--- Surfaces the mod looks after this way (surface index -> spawn position).
local function managed()
  storage.tt_nauvis = storage.tt_nauvis or {}
  return storage.tt_nauvis
end

--- Replace freeplay's extras: no crash site (its ship and debris hold furnaces and drills),
--- and the starting items are the scenario's coal fuel. Freeplay's on_init has already run
--- and waits for these calls.
function M.setup_freeplay()
  local items = {}
  for _, stack in ipairs(map.START_ITEMS) do items[stack.name] = stack.count end
  remote.call("freeplay", "set_disable_crashsite", true)
  remote.call("freeplay", "set_skip_intro", true)
  remote.call("freeplay", "set_created_items", items)
  remote.call("freeplay", "set_respawn_items", {})
end

--- Remove what a chunk area may hold that Tracktorio doesn't allow: enemies anywhere,
--- resources near spawn.
---@param surface LuaSurface
---@param area BoundingBox
---@param spawn MapPosition
---@return integer enemies removed
local function clean(surface, area, spawn)
  local removed = 0
  for _, e in pairs(surface.find_entities_filtered({ area = area, force = "enemy" })) do
    e.destroy()
    removed = removed + 1
  end
  local r2 = M.START_CLEAR * M.START_CLEAR
  local lt, rb = area.left_top or area[1], area.right_bottom or area[2]
  local lx, ly = lt.x or lt[1], lt.y or lt[2]
  local rx, ry = rb.x or rb[1], rb.y or rb[2]
  -- skip chunks wholly outside the clear radius
  local nx = math.max(lx, math.min(spawn.x, rx)) - spawn.x
  local ny = math.max(ly, math.min(spawn.y, ry)) - spawn.y
  if nx * nx + ny * ny > r2 then return removed end
  for _, e in pairs(surface.find_entities_filtered({ area = area, type = "resource" })) do
    local dx, dy = e.position.x - spawn.x, e.position.y - spawn.y
    if dx * dx + dy * dy <= r2 then e.destroy() end
  end
  return removed
end

--- Make a surface a Tracktorio map: biters off, no resources near spawn, the city layout.
--- Returns the placed layout and any missing city labels (scripts/map.lua).
---@param surface LuaSurface
---@param seed integer?
---@param spacing number?
function M.prepare(surface, seed, spacing)
  local force = game.forces["player"]
  local spawn = force.get_spawn_position(surface)
  managed()[surface.index] = { x = spawn.x, y = spawn.y }
  -- biters off: no new bases, no expansion or evolution, peaceful for anything left
  local mgs = surface.map_gen_settings
  mgs.no_enemies_mode = true
  if mgs.autoplace_controls and mgs.autoplace_controls["enemy-base"] then
    mgs.autoplace_controls["enemy-base"] = { frequency = 0, size = 0, richness = 0 }
  end
  surface.map_gen_settings = mgs
  surface.peaceful_mode = true
  game.map_settings.enemy_expansion.enabled = false
  game.map_settings.enemy_evolution.enabled = false
  game.forces["enemy"].reset_evolution()
  -- chunks that exist already (around spawn at the start)
  for chunk in surface.get_chunks() do
    if surface.is_chunk_generated(chunk) then clean(surface, chunk.area, spawn) end
  end
  return map.place_procedural(surface, seed or mgs.seed or 0, spacing or layout.spacing())
end

--- on_chunk_generated: clean chunks of a managed surface as they appear.
---@param e EventData.on_chunk_generated
function M.on_chunk_generated(e)
  local spawn = storage.tt_nauvis and storage.tt_nauvis[e.surface.index]
  if spawn then
    -- counted so a test can tell whether the map generator still places nests after
    -- prepare turned enemy bases off (the clean-up hides it otherwise)
    local n = clean(e.surface, e.area, spawn)
    storage.tt_nauvis_removed = storage.tt_nauvis_removed or {}
    storage.tt_nauvis_removed[e.surface.index] = (storage.tt_nauvis_removed[e.surface.index] or 0) + n
  end
end

--- Is this game the mod's own scenario (New Game -> Mod scenarios -> Tracktorio)?
function M.is_own_scenario()
  return script.level.mod_name == "tracktorio" and script.level.level_name == "tracktorio"
end

M.START_CHART = 200 -- the own scenario charts this far around spawn, as freeplay does

--- on_init (2.8.10): the Tracktorio scenario is the way to play; it sets up Nauvis. Freeplay
--- with the mod on does the same, so nothing breaks, and says where the game really lives
--- (user, playtest 2.8.9). Any other scenario is left alone.
function M.on_init()
  local how
  if M.is_own_scenario() then
    how = "scenario"
  elseif M.is_freeplay() then
    how = "freeplay"
    M.setup_freeplay()
  else
    return
  end
  storage.tt_start = how
  local surface = game.surfaces["nauvis"]
  local placed, missing = M.prepare(surface)
  if how == "scenario" then
    local spawn = game.forces["player"].get_spawn_position(surface)
    local r = M.START_CHART
    game.forces["player"].chart(surface, { { spawn.x - r, spawn.y - r }, { spawn.x + r, spawn.y + r } })
  end
  log(string.format("tracktorio: Nauvis layout (%s): %d cities placed, %d without a site", how, #placed, #missing))
end

--- on_player_created: in the own scenario the mod gives the starting items (freeplay gives
--- them itself); in freeplay it says this is Tracktorio and where to start it properly.
---@param e EventData.on_player_created
function M.on_player_created(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  if storage.tt_start == "scenario" then
    for _, stack in ipairs(map.START_ITEMS) do player.insert(stack) end
    start_kit.give(player)
  elseif storage.tt_start == "freeplay" then
    player.print({ "tt-notify.started-from-freeplay" })
  end
end

function M.remote_interface()
  return {
    prepare = function(surface_name, seed, spacing)
      local placed, missing = M.prepare(assert(game.get_surface(surface_name)), seed, spacing)
      return { placed = placed, missing = missing }
    end,
    start_clear = function() return M.START_CLEAR end,
    setup_freeplay = function() M.setup_freeplay() end,
    --- Tests: run the player-created step as if the game had started `how` ("scenario",
    --- "freeplay"), then restore.
    player_created_as = function(how, player_index)
      local was = storage.tt_start
      storage.tt_start = how
      local ok, err = pcall(M.on_player_created, { name = defines.events.on_player_created, tick = game.tick, player_index = player_index })
      storage.tt_start = was
      if not ok then error(err, 0) end
    end,
    is_own_scenario = function() return M.is_own_scenario() end,
    --- Enemies removed from chunks generated after prepare (0 if the generator places none).
    removed_later = function(surface_name)
      local s = assert(game.get_surface(surface_name))
      return storage.tt_nauvis_removed and storage.tt_nauvis_removed[s.index] or 0
    end,
    is_freeplay = function() return M.is_freeplay() end,
    is_managed = function(surface_name)
      local s = game.get_surface(surface_name)
      return s ~= nil and storage.tt_nauvis ~= nil and storage.tt_nauvis[s.index] ~= nil
    end,
  }
end

return M
