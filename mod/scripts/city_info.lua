-- What a city is doing: recipe, measured output rate, status (running / starved on X /
-- output full). Used by the city GUI and exposed for tests through tt-city.info.
local config = require("shared.config")
local cities = require("scripts.cities")

local M = {}

-- storage.tt_cities[unit].samples = { { tick, products_finished }, ... } over RATE_WINDOW_TICKS

--- Record crafting progress of every crafting city (called every GOAL_TICK_INTERVAL).
function M.sample()
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid and e.type == "assembling-machine" then
      local s = record.samples or {}
      record.samples = s
      s[#s + 1] = { game.tick, e.products_finished }
      while #s > 1 and s[1][1] < game.tick - config.RATE_WINDOW_TICKS do table.remove(s, 1) end
    end
  end
end

---@param entity LuaEntity
---@return LuaRecipePrototype?
local function recipe_of(entity)
  local r = entity.get_recipe()
  return r and prototypes.recipe[r.name] or nil
end

--- Amount of a fluid currently in the entity's input fluidboxes.
local function input_fluid(entity, name)
  local total = 0
  local fb = entity.fluidbox
  for i = 1, #fb do
    local proto = fb.get_prototype(i)
    local fluid = fb[i]
    ---@diagnostic disable-next-line: undefined-field
    if fluid and fluid.name == name and proto and proto.production_type == "input" then
      total = total + fluid.amount
    end
  end
  return total
end

--- Ingredients the city is short of (names). Inputs that are completely absent are named
--- first; only if none are absent, the ones below one cycle's worth.
---@param entity LuaEntity
---@param recipe LuaRecipePrototype
local function missing_inputs(entity, recipe)
  local absent, short = {}, {}
  local inv = entity.get_inventory(defines.inventory.crafter_input)
  for _, ing in ipairs(recipe.ingredients) do
    local have
    if ing.type == "fluid" then
      have = input_fluid(entity, ing.name)
    else
      have = inv and inv.get_item_count(ing.name) or 0
    end
    if have <= 0 then absent[#absent + 1] = ing.name
    elseif have < ing.amount then short[#short + 1] = ing.name end
  end
  return #absent > 0 and absent or short
end

local STARVED = {
  [defines.entity_status.item_ingredient_shortage] = true,
  [defines.entity_status.fluid_ingredient_shortage] = true,
  [defines.entity_status.no_ingredients] = true,
}

--- Snapshot of a city for the UI.
---@param entity LuaEntity
function M.info(entity)
  local record = storage.tt_cities[entity.unit_number] or {}
  local recipe = recipe_of(entity)
  local out = { name = entity.name, unit_number = entity.unit_number }
  if not recipe then out.status = "other"; return out end

  local speed = entity.crafting_speed
  local crafts_per_min_max = 60 * speed / recipe.energy
  out.recipe = {
    name = recipe.name,
    energy = recipe.energy,
    ingredients = {},
    products = {},
  }
  for _, ing in ipairs(recipe.ingredients) do
    out.recipe.ingredients[#out.recipe.ingredients + 1] = {
      type = ing.type, name = ing.name, amount = ing.amount, per_min_max = ing.amount * crafts_per_min_max }
  end

  -- measured crafts per minute over the sample window
  local crafts_per_min = 0
  local s = record.samples
  if s and #s > 1 then
    local minutes = (s[#s][1] - s[1][1]) / 3600
    if minutes > 0 then crafts_per_min = (s[#s][2] - s[1][2]) / minutes end
  end
  for _, p in ipairs(recipe.products) do
    local amount = p.amount or ((p.amount_min + p.amount_max) / 2)
    out.recipe.products[#out.recipe.products + 1] = {
      type = p.type, name = p.name, amount = amount,
      per_min_max = amount * crafts_per_min_max,
      per_min = amount * crafts_per_min,
    }
  end

  local status = entity.status
  if status == defines.entity_status.working or status == defines.entity_status.low_power then
    out.status = "running"
  elseif status == defines.entity_status.full_output then
    out.status = "output_full"
  elseif status and STARVED[status] then
    out.status = "starved"
    out.missing = missing_inputs(entity, recipe)
  else
    out.status = "other"
    for k, v in pairs(defines.entity_status) do if v == status then out.status_detail = k end end
  end
  return out
end

--- Remote twin for tests: info by entity.
function M.remote_info(entity)
  assert(cities.is_city(entity), "tt: not a city")
  return M.info(entity)
end

return M
