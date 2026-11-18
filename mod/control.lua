-- Control stage: runtime only.
local state = require("scripts.state")
local research = require("scripts.research")
local cities = require("scripts.cities")
local debug_cmds = require("scripts.debug")

debug_cmds.register()
cities.register_events()
remote.add_interface("tt-city", cities.remote_interface())

script.on_init(function()
  state.init()
  cities.init()
  research.init()
end)

script.on_configuration_changed(function()
  state.migrate()
  cities.init()
end)
