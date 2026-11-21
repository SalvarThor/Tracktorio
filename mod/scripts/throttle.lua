-- Throttle (PLAN 2.12). A city stands in for many machines but runs as one: fed below its
-- full rate it would craft flat out until its input runs dry, then idle, so its power and
-- status blink. Every crafting city and the research complex get a hidden beacon
-- (prototypes/throttle.lua) whose modules take 5% off speed and power each, and every
-- second this module sets how many, so the city runs steadily at the rate it is fed (or
-- drained). Floor 20% (16 modules): below that it still runs in bursts.
--
-- Crafting cities, each run (rates over the real time since the last run):
--   input side:  crafts done + change in the input stock (in crafts) = crafts fed, averaged
--                over about AVERAGE_S seconds, nudged by how far the stock is from a target
--                of TARGET_S seconds at full speed (the stock sits at the engine's insertion
--                cap when fed fast enough, which hides how much more the belts could give:
--                that pushes the speed up). A second of stock or more: 100%.
--   output side: crafts done - change in the output stock = crafts taken away, averaged
--                the same way; it limits the speed once the output stock is past
--                OUTPUT_HIGH_S seconds of output.
-- The slower side wins. Momentum (playtest 2.12: the percentage jumped about): the speed
-- moves one 5% step at most every HOLD_TICKS, and only when the wanted speed is more than
-- a step away; when the stock is about to run out (under LOW_S) it may slow a step every
-- run, so it doesn't fall back into stop-start. A craft under way counts as input stock.
-- A side where nothing has moved for two seconds stops limiting: with no input at all the
-- city uses up its stock and says starved, with nothing taken away it fills up and says
-- output full, instead of crawling at 20%.
-- The research complex: one step up while it holds two or more of every pack its research
-- needs, one step down when it is short of one.
--
-- record.throttle = { beacon = LuaEntity, steps = integer, fraction = number (0.2-1),
--   last = { finished, input, output, tick }, fed, taken = averaged crafts per second,
--   fed_tick, taken_tick = last tick anything came in / went out, moved_tick = last step }
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")

local M = {}

local TARGET_S = 0.6     -- input stock to keep, in seconds of full-speed crafting
local GAIN = 0.3         -- per target's worth of stock off target, fraction of full speed
                         -- (2.15.7: relative, so a slow city with a long target isn't
                         -- pushed harder; 0.5 per second at the 0.6 s target before)
local OUTPUT_HIGH_S = 1  -- output stock past which the drain rate limits the speed
local IDLE_TICKS = 120   -- nothing fed (or taken) for this long: stop throttling for that side
local PLENTY_S = 1       -- input stock at which it runs flat out (the insertion cap is about 1.2 s)
local AVERAGE_S = 10     -- time constant of the averaged rates
local HOLD_TICKS = 120   -- at least this long between two steps
local LOW_S = 0.2        -- input stock under which it may slow down every run
local MIN_FRACTION = 1 - config.THROTTLE_STEP * config.THROTTLE_MAX_STEPS
-- 2.15.7: at half rates a slow city's TARGET_S is less than one craft's ingredients, and it
-- ran short. The stock targets never go below these, in crafts (what TARGET_S, PLENTY_S
-- and LOW_S were for the depot at 2 crafts/s).
local MIN_TARGET_CRAFTS, MIN_PLENTY_CRAFTS, MIN_LOW_CRAFTS = 1.2, 2, 0.4

--- Does this city get a throttle? Crafting cities with ingredients and the research
--- complex; not power cities (they follow demand), water cities (no inputs), the silo.
---@param city LuaEntity
function M.applies(city)
  local info = city_defs.by_entity[city.name]
  if not info or city_defs.is_power(city.name) then return false end
  if city.type == "lab" then return true end
  if city.type ~= "assembling-machine" then return false end
  local recipe = info.def.recipe
  return recipe ~= nil and recipe.ingredients ~= nil and #recipe.ingredients > 0
end

---@param city LuaEntity
---@param record table
function M.attach(city, record)
  if not M.applies(city) then return end
  local beacon = city.surface.create_entity({ name = config.THROTTLE_BEACON, position = city.position,
    force = city.force, create_build_effect_smoke = false })
  if not beacon then return end
  cities.protect(beacon) -- not operable, minable or destructible, whatever reaches it
  record.throttle = { beacon = beacon, steps = 0, fraction = 1 }
end

---@param record table
function M.detach(record)
  local t = record.throttle
  if t and t.beacon and t.beacon.valid then t.beacon.destroy() end
  record.throttle = nil
end

---@param t table record.throttle
---@param steps integer
local function set_steps(t, steps)
  steps = math.max(0, math.min(config.THROTTLE_MAX_STEPS, steps))
  if steps == t.steps then return end
  local inv = t.beacon.get_inventory(defines.inventory.beacon_modules)
  if not inv then return end
  inv.clear()
  if steps > 0 then inv.insert({ name = config.THROTTLE_MODULE, count = steps }) end
  t.steps = steps
end

--- Stock of a crafting city in crafts: the scarcest input, and the fullest output.
---@param city LuaEntity
---@param recipe LuaRecipePrototype
local function stock(city, recipe)
  local input = math.huge
  local inv = city.get_inventory(defines.inventory.crafter_input)
  for _, ing in ipairs(recipe.ingredients) do
    local have = ing.type == "fluid" and city.get_fluid_count(ing.name) or (inv and inv.get_item_count(ing.name) or 0)
    input = math.min(input, have / ing.amount)
  end
  local output = 0
  local out_inv = city.get_inventory(defines.inventory.crafter_output)
  for _, p in ipairs(recipe.products) do
    local amount = p.amount or p.amount_max or 1
    if amount > 0 then
      local have = p.type == "fluid" and city.get_fluid_count(p.name) or (out_inv and out_inv.get_item_count(p.name) or 0)
      output = math.max(output, have / amount)
    end
  end
  return input == math.huge and 0 or input, output
end

--- One second of control for a crafting city.
---@param city LuaEntity
---@param t table
local function control_crafter(city, t)
  local r = city.get_recipe()
  local recipe = r and prototypes.recipe[r.name]
  if not recipe then return end
  local full = city.prototype.get_crafting_speed() / recipe.energy -- crafts per second at 100%
  local finished = city.products_finished
  local input, output = stock(city, recipe)
  -- a craft under way counts as stock: its ingredients left the inventory when it started
  if city.is_crafting() then input = input + 1 - city.crafting_progress end
  local last = t.last
  t.last = { finished = finished, input = input, output = output, tick = game.tick }
  if not (last and game.tick > last.tick) then return end
  local seconds = (game.tick - last.tick) / 60
  local done = finished - last.finished
  local fed_crafts = done + (input - last.input)
  local taken_crafts = done - (output - last.output)
  if fed_crafts > 1e-6 then t.fed_tick = game.tick end
  if taken_crafts > 1e-6 then t.taken_tick = game.tick end
  local k = math.min(1, seconds / AVERAGE_S)
  t.fed = (t.fed or fed_crafts / seconds) + (fed_crafts / seconds - (t.fed or fed_crafts / seconds)) * k
  t.taken = (t.taken or taken_crafts / seconds) + (taken_crafts / seconds - (t.taken or taken_crafts / seconds)) * k
  local stock_s = input / full
  local target_s = math.max(TARGET_S, MIN_TARGET_CRAFTS / full)
  local plenty_s = math.max(PLENTY_S, MIN_PLENTY_CRAFTS / full)
  local low_s = math.max(LOW_S, MIN_LOW_CRAFTS / full)
  local want
  if game.tick - (t.fed_tick or 0) >= IDLE_TICKS then
    want = 1 -- nothing coming in: use up what is there and say starved, rather than crawl
  elseif stock_s >= plenty_s then
    want = 1 -- plenty stocked: no reason to hold back
  else
    want = t.fed / full + GAIN * (stock_s - target_s) / target_s
  end
  if output / full > OUTPUT_HIGH_S and game.tick - (t.taken_tick or 0) < IDLE_TICKS then
    -- output piling up but still taken away: match the rate it goes (nothing taken at all:
    -- fill up and say output full, rather than crawl)
    want = math.min(want, t.taken / full)
  end
  want = math.max(MIN_FRACTION, math.min(1, want))
  t.want, t.stock_s, t.target_s = want, stock_s, target_s -- for tests and /tt-dump
  local wanted_steps = math.floor((1 - want) / config.THROTTLE_STEP + 0.5)
  local diff = wanted_steps - t.steps
  local urgent = diff > 0 and stock_s < low_s -- about to run dry: slow down now
  if urgent or (math.abs(diff) >= 2 and game.tick - (t.moved_tick or -HOLD_TICKS) >= HOLD_TICKS)
      or (math.abs(diff) == 1 and (wanted_steps == 0 or wanted_steps == config.THROTTLE_MAX_STEPS)
        and game.tick - (t.moved_tick or -HOLD_TICKS) >= HOLD_TICKS) then
    set_steps(t, t.steps + (diff > 0 and 1 or -1))
    t.moved_tick = game.tick
  end
  t.fraction = 1 - t.steps * config.THROTTLE_STEP
end

--- One second of control for the research complex.
---@param city LuaEntity
---@param t table
local function control_lab(city, t)
  local tech = city.force.current_research
  local inv = city.get_inventory(defines.inventory.lab_input)
  if not (tech and inv) then return end
  local least = math.huge
  for _, ing in ipairs(tech.research_unit_ingredients) do least = math.min(least, inv.get_item_count(ing.name)) end
  if least >= 2 then set_steps(t, t.steps - 1) elseif least <= 1 then set_steps(t, t.steps + 1) end
  t.fraction = 1 - t.steps * config.THROTTLE_STEP
end

--- Set a city's steps now (tests).
---@param record table
---@param steps integer
function M.set(record, steps)
  local t = record.throttle
  if not t then return end
  set_steps(t, steps)
  t.fraction = 1 - t.steps * config.THROTTLE_STEP
end

--- Every second (control.lua).
function M.tick()
  for _, record in pairs(storage.tt_cities or {}) do
    local t = record.throttle
    local city = record.entity
    if t and t.beacon.valid and city.valid then
      if city.type == "lab" then control_lab(city, t) else control_crafter(city, t) end
    end
  end
end

--- Speed of a city as a whole percent (100 without a throttle).
---@param record table?
function M.percent(record)
  local t = record and record.throttle
  return t and math.floor((1 - t.steps * config.THROTTLE_STEP) * 100 + 0.5) or 100
end

cities.on_any_placed(M.attach)

return M
