-- City definitions with tiers. Plain data, read by both stages:
--   data stage (prototypes/cities.lua) builds one prototype per tier,
--   control stage reads names, next tiers and upgrade costs.
-- Rates and costs are tuning values; see DECISIONS.md (1.3, Phase 2.1) and PLAN.md 2.1.
--
-- Tier 1 keeps the MVP entity name "tt-city-<name>" (MVP saves load); higher tiers are
-- "tt-city-<name>-t<N>". A tier's `cost` is what its construction port must receive to
-- upgrade INTO that tier. Rule (user): a city's upgrade never uses its own product.
local M = {}

M.PREFIX = "tt-city-"
M.POWER_STEAM_TEMP = 165 -- steam at 165 C carries 30 kJ/unit (0.2 kJ/C above 15 C)

local function item(name, amount) return { type = "item", name = name, amount = amount } end
local function cost(list) return list end

local function smelting(name, ore, plate, other_plate, map_color)
  local function recipe(with_coal)
    local ingredients = { item(ore, 10) }
    if with_coal then ingredients[#ingredients + 1] = item("coal", 1) end
    return { energy_required = 1, ingredients = ingredients, results = { item(plate, 10) } }
  end
  return {
    name = name,
    fuel = "coal", -- an ingredient burnt as fuel: notifications say when a tier drops it
    graphics = { type = "furnace", name = "electric-furnace" },
    map_color = map_color,
    tiers = {
      -- T1: coal-fired, 10 plates/s at speed 1.5 = 15 plates/s (900/min, one yellow belt)
      { crafting_speed = 1.5, recipe = recipe(true) },
      -- T2+: electric, no coal. Electric furnace = 0.625 plates/s at 180 kW, so
      -- 30 plates/s = 48 furnaces = 8.64 MW; 60 plates/s = 17.28 MW.
      { crafting_speed = 3, power = "8.64MW", recipe = recipe(false),
        cost = cost({ { name = other_plate, count = 2000 } }) },
      { crafting_speed = 6, power = "17.28MW", recipe = recipe(false),
        cost = cost({ { name = other_plate, count = 6000 } }) },
    },
  }
end

local function both_plates(n) return { { name = "iron-plate", count = n }, { name = "copper-plate", count = n } } end

local depot_recipe = { energy_required = 1, ingredients = { item("coal", 2) }, results = { item("tt-coal-fuel", 1) } }

local power_recipe = {
  energy_required = 1,
  ingredients = { item("coal", 1), { type = "fluid", name = "water", amount = 150 } },
  results = { { type = "fluid", name = "steam", amount = 150, temperature = M.POWER_STEAM_TEMP } },
}

M.list = {
  smelting("iron-smelting", "iron-ore", "iron-plate", "copper-plate", { r = 0.55, g = 0.6, b = 0.7 }),
  smelting("copper-smelting", "copper-ore", "copper-plate", "iron-plate", { r = 0.8, g = 0.45, b = 0.25 }),
  {
    -- Counts as chemical plants (210 kW, 0.5 fuel/s each): 2 fuel/s = 840 kW at T1.
    name = "depot",
    graphics = { type = "assembling-machine", name = "assembling-machine-3" },
    map_color = { r = 0.3, g = 0.3, b = 0.3 },
    tiers = {
      { crafting_speed = 2, power = "840kW", recipe = depot_recipe },
      { crafting_speed = 4, power = "1.68MW", recipe = depot_recipe, cost = both_plates(1000) },
      { crafting_speed = 8, power = "3.36MW", recipe = depot_recipe, cost = both_plates(3000) },
    },
  },
  {
    -- Coal + water -> steam into a hidden generator. 150 steam per craft; the generator burns
    -- `generator_usage` steam per tick: 3 = 180/s = 5.4 MW, 6 = 10.8 MW, 12 = 21.6 MW.
    name = "power",
    graphics = { type = "assembling-machine", name = "oil-refinery" },
    map_color = { r = 0.9, g = 0.85, b = 0.3 },
    fluid_boxes = {
      { production_type = "input", position = { 0, 4 }, direction = defines.direction.south, filter = "water" },
      { production_type = "output", linked_id = 1, filter = "steam" },
    },
    tiers = {
      { crafting_speed = 1.2, recipe = power_recipe, generator_usage = 3 },
      { crafting_speed = 2.4, recipe = power_recipe, generator_usage = 6, cost = both_plates(1000) },
      { crafting_speed = 4.8, recipe = power_recipe, generator_usage = 12, cost = both_plates(3000) },
    },
  },
}

---@param name string city definition name, e.g. "iron-smelting"
---@param tier integer
function M.entity_name(name, tier)
  return tier == 1 and (M.PREFIX .. name) or (M.PREFIX .. name .. "-t" .. tier)
end

--- Hidden generator of a power city tier (tier 1 keeps the MVP name).
---@param tier integer
function M.generator_name(tier)
  return tier == 1 and "tt-power-generator" or ("tt-power-generator-t" .. tier)
end

-- entity name -> { def = city definition, tier = n, max_tier = n }
M.by_entity = {}
for _, def in ipairs(M.list) do
  for tier in ipairs(def.tiers) do
    M.by_entity[M.entity_name(def.name, tier)] = { def = def, tier = tier, max_tier = #def.tiers }
  end
end

--- Does this city entity feed a hidden generator (a power city of any tier)?
---@param entity_name string
function M.is_power(entity_name)
  local info = M.by_entity[entity_name]
  return info ~= nil and info.def.tiers[info.tier].generator_usage ~= nil
end

--- Entity name of the next tier, or nil at max tier / for non-tiered cities.
---@param entity_name string
function M.next_tier(entity_name)
  local info = M.by_entity[entity_name]
  if not info or info.tier >= info.max_tier then return nil end
  return M.entity_name(info.def.name, info.tier + 1), info.def.tiers[info.tier + 1]
end

return M
