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
local ports = require("scripts.ports")
local upgrade = require("scripts.upgrade")
local debug_cmds = require("scripts.debug")

debug_cmds.register()
cities.register_events()
city_gui.register_events()
limp.register_events()

local city_remote = cities.remote_interface()
city_remote.info = city_info.remote_info
city_remote.has_window = function(entity) return city_gui.has_window(entity) end
city_remote.upgrade_status = function(entity) return ports.status(entity) end
city_remote.port_tick = function() ports.tick() end
city_remote.upgrade_now = function(entity) return upgrade.upgrade(assert(storage.tt_cities[entity.unit_number])) end
city_remote.open_gui = function(player_index, entity)
  local player = assert(game.get_player(player_index))
  city_gui.open(player, entity)
end
remote.add_interface("tt-city", city_remote)
remote.add_interface("tt-goal", goal.remote_interface())
remote.add_interface("tt-limp", limp.remote_interface())
remote.add_interface("tt-map", map.remote_interface())

script.on_init(function()
  state.init()
  cities.init()
  goal.init()
  city_gui.init()
  limp.scan()
  research.init()
  goal_gui.rebuild_all()
end)

script.on_configuration_changed(function()
  state.migrate()
  cities.init()
  goal.init()
  city_gui.init()
  limp.scan()
  goal_gui.rebuild_all()
end)

script.on_event(defines.events.on_player_created, goal_gui.on_player_created)

script.on_nth_tick(config.GOAL_TICK_INTERVAL, function()
  goal.tick()
  ports.tick()
  goal_gui.update_all()
  city_info.sample()
  city_gui.update_all()
  map.tick_tags()
end)

script.on_nth_tick(config.LIMP_INTERVAL, limp.tick)
