-- Control stage: runtime only.
local state = require("scripts.state")
local research = require("scripts.research")
local debug_cmds = require("scripts.debug")

debug_cmds.register()

script.on_init(function()
  state.init()
  research.init()
end)

script.on_configuration_changed(function()
  state.migrate()
end)
