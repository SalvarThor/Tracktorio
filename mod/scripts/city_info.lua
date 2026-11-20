-- What a city is doing: recipe, measured output rate, status (running / starved on X /
-- output full). Used by the city GUI and exposed for tests through tt-city.info.
local config = require("shared.config")
local cities = require("scripts.cities")
local city_defs = require("shared.city_defs")
local port_layout = require("shared.port_layout")
local silo = require("scripts.silo")
local nuclear = require("scripts.nuclear")

local M = {}

-- storage.tt_cities[unit].samples = { { tick, products_finished }, ... } over RATE_WINDOW_TICKS

--- Record crafting progress of every crafting city (called every GOAL_TICK_INTERVAL).
function M.sample()
  for _, record in pairs(storage.tt_cities) do
    local e = record.entity
    if e.valid and (e.type == "assembling-machine" or e.type == "rocket-silo") then
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

--- Amount of an ingredient fluid in the entity. 2.1 removed LuaEntity.fluidbox/LuaFluidBox;
--- get_fluid_count covers all of the entity's fluid storages. A city's fluid ingredients and
--- fluid products are different fluids (water in, steam out), so this is the input amount.
---@param entity LuaEntity
---@param name string
local function input_fluid(entity, name)
  return entity.get_fluid_count(name)
end

--- Fuel item of a burner city (the nuclear city), or nil.
---@param entity LuaEntity
local function burner_fuel(entity)
  local info = city_defs.by_entity[entity.name]
  return info and info.def.burner and info.def.burner.fuel or nil
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
  -- Burner cities (nuclear, 2.6.4): out of fuel when nothing is burning or waiting.
  local fuel = burner_fuel(entity)
  if fuel and entity.burner and (entity.burner.remaining_burning_fuel or 0) <= 0
    and entity.get_fuel_inventory().get_item_count(fuel) == 0 then
    absent[#absent + 1] = fuel
  end
  return #absent > 0 and absent or short
end

local STARVED = {
  [defines.entity_status.item_ingredient_shortage] = true,
  [defines.entity_status.fluid_ingredient_shortage] = true,
  [defines.entity_status.no_ingredients] = true,
  [defines.entity_status.no_fuel] = true,
}

local LAB_STATUS = {
  [defines.entity_status.working] = "running",
  [defines.entity_status.low_power] = "low_power",
  [defines.entity_status.no_power] = "no_power",
  [defines.entity_status.no_research_in_progress] = "no_research",
  [defines.entity_status.missing_science_packs] = "missing_packs",
}

--- Snapshot of the research complex (a lab, PLAN 2.2.3).
---@param entity LuaEntity
local function lab_info(entity)
  local out = { name = entity.name, unit_number = entity.unit_number }
  local inv = entity.get_inventory(defines.inventory.lab_input)
  local accepts = {}
  out.lab = { speed = entity.prototype.get_researching_speed(), packs = {} }
  for _, pack in ipairs(entity.prototype.lab_inputs or {}) do
    accepts[pack] = true
    out.lab.packs[#out.lab.packs + 1] = { type = "item", name = pack, count = inv and inv.get_item_count(pack) or 0 }
  end
  local tech = entity.force.current_research
  out.research = tech and tech.name or nil
  out.status = LAB_STATUS[entity.status] or "other"
  if out.status == "other" then
    for k, v in pairs(defines.entity_status) do if v == entity.status then out.status_detail = k end end
  end
  if tech then
    out.missing, out.unsupported = {}, {}
    for _, ing in ipairs(tech.research_unit_ingredients) do
      if not accepts[ing.name] then out.unsupported[#out.unsupported + 1] = ing.name
      elseif (inv and inv.get_item_count(ing.name) or 0) == 0 then out.missing[#out.missing + 1] = ing.name end
    end
  end
  return out
end

--- Where the player connects pipes (2.4.2): one entry per piped fluid at this tier, from
--- the port layout (2.10), { kind = "input"|"output", fluid, side, offset }. offset is
--- tiles along the wall from its middle: + is east on the north/south walls, south on the
--- east/west walls.
---@param entity_name string
function M.connections(entity_name)
  local info = city_defs.by_entity[entity_name]
  local out = {}
  if not info then return out end
  for _, p in ipairs(port_layout.ports(info.def)) do
    if p.kind == "fluid" and p.tiers[info.tier] then
      out[#out + 1] = { kind = p.flow, fluid = p.name, side = p.wall, offset = p.offset }
    end
  end
  return out
end

--- Products holding up a city whose output is full: fluids with no room for one more
--- cycle, items with at least one cycle waiting. Falls back to every product.
---@param entity LuaEntity
---@param recipe LuaRecipePrototype
local function full_products(entity, recipe)
  local info = city_defs.by_entity[entity.name]
  local volume = {}
  for _, f in ipairs(info and info.def.fluid_boxes or {}) do
    if f.production_type == "output" and f.filter then volume[f.filter] = f.volume or 1000 end
  end
  local inv = entity.get_inventory(defines.inventory.crafter_output)
  local full, all = {}, {}
  for _, p in ipairs(recipe.products) do
    local amount = p.amount or p.amount_max or 1
    all[#all + 1] = p.name
    if p.type == "fluid" then
      if volume[p.name] and entity.get_fluid_count(p.name) + amount > volume[p.name] then full[#full + 1] = p.name end
    elseif inv and inv.get_item_count(p.name) >= amount then
      full[#full + 1] = p.name
    end
  end
  return #full > 0 and full or all
end

--- Snapshot of a city for the UI.
---@param entity LuaEntity
function M.info(entity)
  if entity.type == "lab" then return lab_info(entity) end
  local record = storage.tt_cities[entity.unit_number] or {}
  local recipe = recipe_of(entity)
  local out = { name = entity.name, unit_number = entity.unit_number, connections = M.connections(entity.name) }
  if entity.type == "rocket-silo" then out.silo = silo.status(entity) end
  if not recipe then out.status = "other"; return out end

  local speed = entity.crafting_speed
  local crafts_per_min_max = 60 * speed / recipe.energy
  out.recipe = {
    name = recipe.name,
    energy = recipe.energy,
    ingredients = {},
    products = {},
  }
  local input_inv = entity.get_inventory(defines.inventory.crafter_input)
  for _, ing in ipairs(recipe.ingredients) do
    -- have: what is in the city now (playtest 2.4.6: the window showed nothing before power)
    local have = ing.type == "fluid" and input_fluid(entity, ing.name) or (input_inv and input_inv.get_item_count(ing.name) or 0)
    out.recipe.ingredients[#out.recipe.ingredients + 1] = {
      type = ing.type, name = ing.name, amount = ing.amount, per_min_max = ing.amount * crafts_per_min_max, have = have }
  end

  -- Burner cities list their fuel as an input: per_min_max at full output.
  local fuel = burner_fuel(entity)
  if fuel then
    local watts = entity.prototype.get_max_energy_usage() * 60
    local fuel_inv = entity.get_fuel_inventory()
    out.recipe.ingredients[#out.recipe.ingredients + 1] = {
      type = "item", name = fuel, amount = 1, fuel = true,
      per_min_max = watts * 60 / prototypes.item[fuel].fuel_value,
      have = fuel_inv and fuel_inv.get_item_count(fuel) or 0 }
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

  -- Nuclear: how much of its flat-out output is used (the rest is vented).
  if nuclear.is_flat_out(entity.name) then out.power_use = nuclear.power_use(record) end

  local status = entity.status
  if status == defines.entity_status.working then
    out.status = "running"
  elseif status == defines.entity_status.low_power then
    out.status = "low_power"
    out.also_missing = missing_inputs(entity, recipe)
  elseif status == defines.entity_status.no_power then
    out.status = "no_power"
    out.also_missing = missing_inputs(entity, recipe)
  elseif status == defines.entity_status.full_output then
    out.status = "output_full"
    out.full = full_products(entity, recipe)
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
