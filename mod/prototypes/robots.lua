-- Personal construction robots (user, 2026-11-21) are fast: building is free, so building
-- should be quick. Like the user's Speedy Bot Start: config.ROBOT_SPEED_FACTOR times the
-- vanilla speed, and no energy use, so they never wait at a personal roboport to recharge.
-- Data stage, final fixes (a vanilla prototype).
local config = require("shared.config")

local bot = data.raw["construction-robot"]["construction-robot"]
if bot then
  bot.speed = 0.06 * config.ROBOT_SPEED_FACTOR
  bot.max_energy = "0MJ"
  bot.energy_per_tick = "0kJ"
  bot.energy_per_move = "0kJ"
  bot.speed_multiplier_when_out_of_energy = 1
end
