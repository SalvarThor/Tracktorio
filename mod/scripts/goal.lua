-- Win condition. Since 2.5.7 (user): launching the first rocket from the rocket silo city
-- wins. The MVP goal box (cumulative iron and copper plates) only exists in older saves; it
-- still counts deliveries but no longer decides the win.
--
-- storage.tt_goal = {
--   delivered = { iron = n, copper = n },
--   samples = { { tick, iron, copper }, ... }  -- cumulative totals, for rate per minute
--   won = bool, won_tick = tick?
-- }
local config = require("shared.config")
local cities = require("scripts.cities")

local M = {}

function M.init()
  storage.tt_goal = storage.tt_goal or {
    delivered = { iron = 0, copper = 0 },
    samples = {},
    won = false,
  }
end

function M.targets()
  return {
    iron = settings.global["tt-goal-iron"].value --[[@as integer]],
    copper = settings.global["tt-goal-copper"].value --[[@as integer]],
  }
end

--- Slot filters follow the totals: a metal whose target is met is filtered to a placeholder
--- nothing can match, so the box stops accepting it (it only takes what it still needs).
---@param entity LuaEntity
local function set_filters(entity)
  local inv = assert(entity.get_inventory(defines.inventory.chest))
  local half = math.floor(#inv / 2)
  local t = M.targets()
  local d = storage.tt_goal and storage.tt_goal.delivered or { iron = 0, copper = 0 }
  local want = {
    iron = d.iron < t.iron and config.GOAL_ITEMS.iron or config.GOAL_CLOSED_ITEM,
    copper = d.copper < t.copper and config.GOAL_ITEMS.copper or config.GOAL_CLOSED_ITEM,
  }
  for i = 1, #inv do
    local name = i <= half and want.iron or want.copper
    local current = inv.get_filter(i)
    if not current or current.name ~= name then inv.set_filter(i, { name = name }) end
  end
end
cities.on_placed(config.CITY.goal, set_filters)

local function refresh_filters()
  for _, box in ipairs(cities.list(config.CITY.goal)) do set_filters(box) end
end

--- Delivered plates per minute over the rate window: { iron = n, copper = n }.
function M.rates()
  local s = storage.tt_goal.samples
  local last, first = s[#s], s[1]
  if not last or last == first then return { iron = 0, copper = 0 } end
  local minutes = (last[1] - first[1]) / 3600
  return {
    iron = (last[2] - first[2]) / minutes,
    copper = (last[3] - first[3]) / minutes,
  }
end

--- A rocket left a rocket silo city: the first one wins (2.5.7).
---@param silo LuaEntity?
function M.rocket_launched(silo)
  M.init()
  local g = storage.tt_goal
  if g.won then return end
  g.won = true
  g.won_tick = game.tick
  g.won_by = "rocket"
  game.set_win_ending_info({ title = { "tt-gui.victory-title" }, message = { "tt-gui.victory-rocket" } })
  game.set_game_state({ game_finished = true, player_won = true, can_continue = true })
end

--- Empty every goal box, count what arrived, record a sample, check the win.
function M.tick()
  local g = storage.tt_goal
  for _, box in ipairs(cities.list(config.CITY.goal)) do
    local inv = assert(box.get_inventory(defines.inventory.chest))
    for key, item in pairs(config.GOAL_ITEMS) do
      local n = inv.get_item_count(item)
      if n > 0 then
        inv.remove({ name = item, count = n })
        g.delivered[key] = g.delivered[key] + n
      end
    end
  end
  refresh_filters()
  local samples = g.samples
  samples[#samples + 1] = { game.tick, g.delivered.iron, g.delivered.copper }
  while #samples > 1 and samples[1][1] < game.tick - config.RATE_WINDOW_TICKS do
    table.remove(samples, 1)
  end
end

function M.status()
  local g = storage.tt_goal
  return {
    delivered = { iron = g.delivered.iron, copper = g.delivered.copper },
    targets = M.targets(),
    rates = M.rates(),
    won = g.won,
    won_tick = g.won_tick,
  }
end

--- Change the targets (runtime-global settings can only be written by this mod).
---@param iron integer?
---@param copper integer?
function M.set_targets(iron, copper)
  if iron then settings.global["tt-goal-iron"] = { value = math.max(1, math.floor(iron)) } end
  if copper then settings.global["tt-goal-copper"] = { value = math.max(1, math.floor(copper)) } end
  refresh_filters()
end

function M.remote_interface()
  return {
    status = M.status,
    set_targets = M.set_targets,
    --- Count deliveries now instead of waiting for the next interval (tests).
    tick = M.tick,
  }
end

return M
