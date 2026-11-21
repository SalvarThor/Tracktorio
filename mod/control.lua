-- Control stage: runtime only.
local config = require("shared.config")
local state = require("scripts.state")
local research = require("scripts.research")
local cities = require("scripts.cities")
local goal = require("scripts.goal")
local goal_gui = require("scripts.goal_gui")
local city_info = require("scripts.city_info")
local city_gui = require("scripts.city_gui")
local limp = require("scripts.limp")
local map = require("scripts.map")
local belt_ports = require("scripts.belt_ports") -- 2.10.4: registers its placement hook
local signals = require("scripts.signals") -- 2.11: registers its placement hook
local throttle = require("scripts.throttle") -- 2.12: registers its placement hook
local notify = require("scripts.notify")
local reliability = require("scripts.reliability")
local service = require("scripts.service")
local silo = require("scripts.silo")
local nuclear = require("scripts.nuclear")
local nauvis = require("scripts.nauvis")
local debug_cmds = require("scripts.debug")

debug_cmds.register()
cities.register_events()
city_gui.register_events()
-- Build events: one handler per event, shared by the modules that care (2.10.5).
---@param e EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive|EventData.on_entity_cloned
local function on_built(e)
  local entity = e.entity or e.destination
  if not (entity and entity.valid) then return end
  cities.on_built(entity) -- 2.15: the player builds cities
  if not entity.valid then return end
  limp.on_built(entity)
  belt_ports.check_inserter(entity, e.player_index)
end
do
  local filter = { { filter = "type", type = "locomotive" }, { filter = "type", type = "inserter" } }
  for _, f in ipairs(cities.BUILD_FILTER) do filter[#filter + 1] = f end
  script.on_event(defines.events.on_built_entity, on_built, filter)
  script.on_event(defines.events.on_robot_built_entity, on_built, filter)
  script.on_event(defines.events.script_raised_built, on_built, filter)
  script.on_event(defines.events.script_raised_revive, on_built, filter)
  script.on_event(defines.events.on_entity_cloned, on_built, filter)
end
script.on_event(defines.events.on_player_rotated_entity, function(e)
  belt_ports.check_inserter(e.entity, e.player_index)
end)
script.on_event(defines.events.on_tick, function()
  belt_ports.tick()
  belt_ports.balance()
end)
silo.register_events()

local migrate -- defined below; used by the tt-city.migrate test hook
local require_start_kit = require("scripts.start_kit")

local city_remote = cities.remote_interface()
city_remote.info = city_info.remote_info
city_remote.has_window = function(entity) return city_gui.has_window(entity) end
city_remote.open_gui = function(player_index, entity)
  local player = assert(game.get_player(player_index))
  city_gui.open(player, entity)
end
city_remote.recent_messages = function() return notify.recent() end
city_remote.service_status = function(entity) return service.status(entity) end
city_remote.service_tick = function(seconds) service.tick(seconds) end
city_remote.silo_status = function(entity) return silo.status(entity) end
city_remote.silo_tick = function() silo.tick() end
city_remote.nuclear_tick = function() return nuclear.tick() end
city_remote.silo_fill = function(entity, parts)
  assert(silo.is_silo(entity), "not a rocket silo city")
  entity.rocket_parts = math.max(0, math.min(entity.prototype.rocket_parts_required - 1, math.floor(parts)))
end
city_remote.alerts_pending = function() return #(storage.tt_alerts or {}) end
-- Tests: queue an inserter as if `player_index` had built it (2.10.5).
city_remote.check_inserter = function(entity, player_index) belt_ports.check_inserter(entity, player_index) end
city_remote.inserters_refused = function() return storage.tt_inserters_refused or 0 end
city_remote.network_warning = function(entity) return notify.network_warning(entity) end
-- Tests: a city's signal points (2.11) and an immediate rewrite of their signals.
city_remote.signal_points = function(entity)
  local record = assert(storage.tt_cities[entity.unit_number])
  return record.signal_points or {}
end
city_remote.signals_tick = function() signals.tick() end
-- Tests: a city's throttle (2.12) and one second of its control.
city_remote.throttle = function(entity)
  local record = assert(storage.tt_cities[entity.unit_number])
  local t = record.throttle
  return t and { steps = t.steps, fraction = t.fraction, percent = throttle.percent(record), beacon = t.beacon } or nil
end
city_remote.throttle_tick = function() throttle.tick() end
-- Tests: give a player the start kit again (personal construction robots, 2026-11-21).
city_remote.give_start_kit = function(player_index)
  if storage.tt_start_kit then storage.tt_start_kit[player_index] = nil end
  require_start_kit.give(assert(game.get_player(player_index)))
end
city_remote.throttle_set = function(entity, steps) throttle.set(assert(storage.tt_cities[entity.unit_number]), steps) end
-- Tests: run the configuration-change handler.
city_remote.migrate = function(from_schema)
  if from_schema then storage.tt_schema = from_schema end
  migrate()
end
remote.add_interface("tt-city", city_remote)

silo.on_launched(goal.rocket_launched)
map.on_city_blocked(notify.city_blocked)
map.on_lake_blocked(notify.lake_blocked)
reliability.on_breakdown(notify.breakdown)
reliability.on_cured(notify.repaired)
remote.add_interface("tt-goal", goal.remote_interface())
remote.add_interface("tt-limp", limp.remote_interface())
remote.add_interface("tt-map", map.remote_interface())
remote.add_interface("tt-nauvis", nauvis.remote_interface())
remote.add_interface("tt-reliability", {
  get = function(loco) return reliability.fraction(loco) end,
  set = function(loco, fraction) reliability.set(loco, fraction) end,
  --- Tests: apply `ticks` of driving wear now.
  wear = function(loco, ticks) reliability.wear(loco, ticks) end,
  chance = function(fraction, ticks) return reliability.chance(fraction, ticks) end,
  is_broken = function(loco) return reliability.is_broken(loco) end,
  --- Tests: break a locomotive down now.
  break_down = function(loco) reliability.break_down(loco) end,
})
script.on_init(function()
  state.init()
  cities.init()
  goal.init()
  city_gui.init()
  notify.init()
  reliability.init()
  silo.init()
  limp.scan()
  research.init()
  goal_gui.rebuild_all()
  nauvis.on_init() -- 2.8.4: a New Game lays out Nauvis
end)

script.on_event(defines.events.on_chunk_generated, nauvis.on_chunk_generated)
script.on_event(defines.events.on_chunk_charted, map.on_chunk_charted)
script.on_event(defines.events.on_surface_deleted, function(e)
  if storage.tt_nauvis then storage.tt_nauvis[e.surface_index] = nil end
  if storage.tt_nauvis_removed then storage.tt_nauvis_removed[e.surface_index] = nil end
  if storage.tt_layout then
    for name in pairs(storage.tt_layout) do
      if not game.get_surface(name) then storage.tt_layout[name] = nil end
    end
  end
end)

migrate = function()
  local from = storage.tt_schema
  cities.init()
  goal.init()
  city_gui.init()
  notify.init()
  reliability.init()
  silo.init()
  state.migrate()
  research.init() -- start technologies added later (e.g. 2.2.3) reach existing saves
  -- Grow an existing scenario map to the current layout (2.2.6: new cities, bigger map).
  local surface = game.get_surface(map.SURFACE)
  if surface then map.extend(surface) end
  service.ensure_all() -- 2.3.4: depots get their service port
  local total = 0
  for _, r in pairs(storage.tt_cities) do
    if r.entity.valid then total = total + 1 end
  end
  local blocked = 0
  for _ in pairs(storage.tt_map_blocked or {}) do blocked = blocked + 1 end
  local depots, serviced = 0, 0
  for _, r in pairs(storage.tt_cities) do
    if r.entity.valid and service.has_service(r.name) then
      depots = depots + 1
      if r.service_port and r.service_port.valid then serviced = serviced + 1 end
    end
  end
  log(string.format("tt: configuration changed: schema %s -> %d; cities: %d (spots blocked: %d); depots with a service port: %d/%d",
    tostring(from), storage.tt_schema, total, blocked, serviced, depots))
  limp.scan()
  goal_gui.rebuild_all()
end

script.on_configuration_changed(migrate)

script.on_event(defines.events.on_player_created, function(e)
  goal_gui.on_player_created(e)
  nauvis.on_player_created(e)
end)

script.on_nth_tick(config.GOAL_TICK_INTERVAL, function()
  goal.tick()
  service.tick()
  silo.tick()
  nuclear.tick()
  goal_gui.update_all()
  city_info.sample()
  city_gui.update_all()
  map.tick_tags()
  map.retry_blocked()
  notify.tick()
  throttle.tick()
  signals.tick()
end)

script.on_nth_tick(config.LIMP_INTERVAL, limp.tick)
