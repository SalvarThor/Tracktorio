-- Starting research (SPEC MVP).
local config = require("shared.config")

local M = {}

---@param force LuaForce
function M.apply_start(force)
  for _, name in ipairs(config.START_TECHNOLOGIES) do
    local tech = force.technologies[name]
    if tech then
      tech.researched = true
    else
      log("tt: start technology missing: " .. name)
    end
  end
end

function M.init()
  M.apply_start(game.forces["player"])
end

return M
