-- Throttle (PLAN 2.12). A city stands in for many machines but runs as one: fed below its
-- full rate it would craft flat out until its input runs dry, then idle, so its power and
-- status blink. Every crafting city and the research complex get a hidden beacon
-- (prototypes/throttle.lua) whose modules take 5% off speed and power each, and every
-- second this module sets how many, so the city runs steadily at the rate it is fed (or
-- drained). Floor 20% (16 modules): below that it still runs in bursts.
--
-- Crafting cities: the rate it can keep up is estimated from the last second:
--   input side:  crafts done + change in the input stock (in crafts) = crafts fed per second,
--                nudged by how far the stock is from a target of TARGET_S seconds at full
--                speed (the stock sits at the engine's insertion cap when fed fast enough,
--                which hides how much more the belts could give: that pushes the speed up);
--   output side: crafts done - change in the output stock = crafts taken away per second,
--                only once the output stock is past OUTPUT_HIGH_S seconds of output.
-- The slower side wins, smoothed (half of the new value each second). A craft under way
-- counts as input stock. A side where nothing has moved for two seconds stops limiting:
-- with no input at all the city uses up its stock and says starved, with nothing taken
-- away it fills up and says output full, instead of crawling at 20%.
-- The research complex: one step up while it holds two or more of every pack its research
-- needs, one step down when it is short of one.
--
-- record.throttle = { beacon = LuaEntity, steps = integer, fraction = number (0.2-1),
--   last = { finished, input, output, tick }, fed_tick, taken_tick = last tick anything
--   came in / went out }
local config = require("shared.config")
local city_defs = require("shared.city_defs")
local cities = require("scripts.cities")

local M = {}

local TARGET_S = 0.6     -- input stock to keep, in seconds of full-speed crafting
local GAIN = 0.5         -- per second of stock off target, fraction of full speed
local OUTPUT_HIGH_S = 1  -- output stock past which the drain rate limits the speed
local IDLE_TICKS = 120   -- nothing fed (or taken) for this long: stop throttling for that side
local PLENTY_S = 1       -- input stock at which it runs flat out (the insertion cap is about 1.2 s)
local MIN_FRACTION = 1 - config.THROTTLE_STEP * config.THROTTLE_MAX_STEPS

--- Does this city get a throttle? Crafting cities with ingredients and the research
--- complex; not power cities (they follow demand), water cities (no inputs), the silo.
---@param city LuaEntity
function M.applies(city)
  local info = city_defs.by_entity[city.name]
  if not info or city_defs.is_power(city.name) then return false end
  if city.type == "lab" then return true end
  if city.type ~= "assembling-machine" then return false end
  local recipe = info.def.tiers[info.tier].recipe
  return recipe ~= nil and recipe.ingredients ~= nil and #recipe.ingredients > 0
end

---@param city LuaEntity
---@param record table
function M.attach(city, record)
  if not M.applies(city) then return end
  local beacon = city.surface.create_entity({ name = config.THROTTLE_BEACON, position = city.position,
    force = city.force, create_build_effect_smoke = false })
  if not beacon then return end
  beacon.destructible = false
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
  local want
  if game.tick - (t.fed_tick or 0) >= IDLE_TICKS then
    want = 1 -- nothing coming in: use up what is there and say starved, rather than crawl
  else
    want = fed_crafts / seconds / full + GAIN * (input / full - TARGET_S)
    if input / full >= PLENTY_S then want = 1 end -- a full second stocked: no reason to hold back
  end
  if output / full > OUTPUT_HIGH_S and game.tick - (t.taken_tick or 0) < IDLE_TICKS then
    -- output piling up but still taken away: match the rate it goes (nothing taken at all:
    -- fill up and say output full, rather than crawl)
    want = math.min(want, taken_crafts / seconds / full)
  end
  want = math.max(MIN_FRACTION, math.min(1, want))
  local k = math.min(1, seconds / 2) -- smoothing: half the way per second
  t.fraction = t.fraction + (want - t.fraction) * k
  set_steps(t, math.floor((1 - t.fraction) / config.THROTTLE_STEP + 0.5))
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
