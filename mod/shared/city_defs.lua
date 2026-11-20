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
M.NUCLEAR_STEAM_TEMP = 500 -- 97 kJ/unit, as from vanilla heat exchangers (2.6.4)

--- Energy in one unit of steam at `temp` C (water heat capacity 0.2 kJ/C, from 15 C).
---@param temp number
function M.steam_joules(temp) return (temp - 15) * 200 end

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
      -- T3 (2.2.5): part of the cost moves to circuits
      { crafting_speed = 6, power = "17.28MW", recipe = recipe(false),
        cost = cost({ { name = other_plate, count = 3000 }, { name = "electronic-circuit", count = 1000 } }) },
    },
  }
end

local function both_plates(n) return { { name = "iron-plate", count = n }, { name = "copper-plate", count = n } } end

local function with_circuits(plates, circuits)
  local c = both_plates(plates)
  c[#c + 1] = { name = "electronic-circuit", count = circuits }
  return c
end

local depot_recipe = { energy_required = 1, ingredients = { item("coal", 2) }, results = { item("tt-coal-fuel", 1) } }

local power_recipe = {
  energy_required = 1,
  ingredients = { item("coal", 1), { type = "fluid", name = "water", amount = 150 } },
  results = { { type = "fluid", name = "steam", amount = 150, temperature = M.POWER_STEAM_TEMP } },
}

-- Intermediate cities (PLAN 2.2.2). Power = the vanilla assembling machine 2s (speed 0.75,
-- 150 kW) that would make the same output; gears and cables are made inside the city.
local function assembler_city(name, graphics, map_color, power_t1, recipe, speed_t1, t3_cost, fluid_boxes)
  local function mw(f) return string.format("%gkW", power_t1 * f) end
  return {
    name = name,
    graphics = graphics,
    map_color = map_color,
    fluid_boxes = fluid_boxes,
    tiers = {
      { crafting_speed = speed_t1, power = mw(1), recipe = recipe },
      { crafting_speed = speed_t1 * 2, power = mw(2), recipe = recipe, cost = both_plates(1000) },
      { crafting_speed = speed_t1 * 4, power = mw(4), recipe = recipe, cost = t3_cost },
    },
  }
end


-- Circuits: 1 iron + 1.5 copper each (3 cables). 5 circuits/s needs 3.33 assemblers for
-- circuits + 5 for cables = 8.33 x 150 kW = 1.25 MW.
local circuit_recipe = { energy_required = 0.2,
  ingredients = { item("iron-plate", 2), item("copper-plate", 3) }, results = { item("electronic-circuit", 2) } }
-- Red science: 1 gear (2 iron) + 1 copper, 5 s. 1 pack/s = 6.67 + 0.67 assemblers = 1.1 MW.
local red_recipe = { energy_required = 1,
  ingredients = { item("iron-plate", 2), item("copper-plate", 1) }, results = { item("automation-science-pack", 1) } }
-- Green science: inserter (1 circuit, 1 gear, 1 iron) + belt (half of 1 gear + 1 iron -> 2),
-- 6 s: 4.5 iron + 1 circuit per pack. 1 pack/s = 8 + 0.67 + 0.33 + 1 (gears) = 10 assemblers
-- = 1.5 MW.
local green_recipe = { energy_required = 2,
  ingredients = { item("iron-plate", 9), item("electronic-circuit", 2) }, results = { item("logistic-science-pack", 2) } }
-- Repair packs (2.3.4): 2 circuits + 2 gears (4 iron), 0.5 s (vanilla). 30 packs/min = 1
-- assembler 2 for the packs' 0.33 + 0.67 for gears = 150 kW.
local repair_recipe = { energy_required = 1,
  ingredients = { item("iron-plate", 4), item("electronic-circuit", 2) }, results = { item("repair-pack", 1) } }

-- Refinery (2.4.3): vanilla advanced oil processing (100 crude + 50 water -> 25 heavy +
-- 45 light + 55 gas, 5 s) with the heavy oil cracked inside (25 heavy + ~19 water -> ~19
-- light), rounded. Speed 2 = 2 refineries: 40 crude/s -> 26 light/s + 22 gas/s,
-- 2 x 420 kW + 0.5 chemical plant (cracking) = ~0.95 MW.
local function fluid(name, amount) return { type = "fluid", name = name, amount = amount } end
local refinery_recipe = { energy_required = 5,
  ingredients = { fluid("crude-oil", 100), fluid("water", 70) },
  results = { fluid("light-oil", 65), fluid("petroleum-gas", 55) } }

-- Fuel depots (2.4.4): vanilla recipes. Solid fuel from light oil: 10 -> 1 in 1 s; speed 2
-- = 2 chemical plants (210 kW each): 2 solid fuel/s from 20 light oil/s. Rocket fuel: 10
-- solid fuel + 10 light oil -> 1 in 15 s; speed 3 = 4 assemblers 2 (150 kW each):
-- 0.2 rocket fuel/s from 2 solid fuel/s + 2 light oil/s.
local solid_fuel_recipe = { energy_required = 1,
  ingredients = { fluid("light-oil", 10) }, results = { item("solid-fuel", 1) } }
local rocket_fuel_recipe = { energy_required = 15,
  ingredients = { item("solid-fuel", 10), fluid("light-oil", 10) }, results = { item("rocket-fuel", 1) } }

-- Steel (2.5.1): 5 iron -> 1 steel in 16 s (vanilla). Speed 16 = 8 electric furnaces
-- (speed 2, 180 kW each): 1 steel/s from 5 iron/s, 1.44 MW. Electric from tier 1.
local steel_recipe = { energy_required = 16,
  ingredients = { item("iron-plate", 5) }, results = { item("steel-plate", 1) } }

-- Chemistry (2.5.2), vanilla recipes in chemical plants (210 kW each, speed 1).
-- Plastic: 20 gas + 1 coal -> 2 in 1 s; speed 1.5 = 3 plastic/s, 315 kW.
local plastic_recipe = { energy_required = 1,
  ingredients = { fluid("petroleum-gas", 20), item("coal", 1) }, results = { item("plastic-bar", 2) } }
-- Sulfur: 30 water + 30 gas -> 2 in 1 s; speed 0.5 = 1 sulfur/s, 105 kW.
local sulfur_recipe = { energy_required = 1,
  ingredients = { fluid("petroleum-gas", 30), fluid("water", 30) }, results = { item("sulfur", 2) } }
-- Sulfuric acid: 5 sulfur + 1 iron + 100 water -> 50 in 1 s; speed 0.1 = 5 acid/s
-- (0.1 chemical plant; power floored at 100 kW).
local acid_recipe = { energy_required = 1,
  ingredients = { item("sulfur", 5), item("iron-plate", 1), fluid("water", 100) },
  results = { fluid("sulfuric-acid", 50) } }

local S, N = defines.direction.south, defines.direction.north
local function pipe_in(x, f) return { production_type = "input", position = { x, 4 }, direction = S, filter = f } end
local function pipe_out(x, f) return { production_type = "output", position = { x, -4 }, direction = N, filter = f } end

-- Electronics (2.5.3), vanilla recipes in assemblers 2 (speed 0.75, 150 kW).
-- Advanced circuit: 2 circuits + 2 plastic + 4 cables (2 copper) -> 1 in 6 s; speed 6 =
-- 1/s = 8 assemblers + 1 for cables = 1.35 MW.
local advanced_recipe = { energy_required = 6,
  ingredients = { item("electronic-circuit", 2), item("plastic-bar", 2), item("copper-plate", 2) },
  results = { item("advanced-circuit", 1) } }
-- Processing unit: 20 circuits + 2 advanced circuits + 5 sulfuric acid -> 1 in 10 s;
-- speed 2 = 0.2/s = 2.67 assemblers = 400 kW.
local processing_recipe = { energy_required = 10,
  ingredients = { item("electronic-circuit", 20), item("advanced-circuit", 2), fluid("sulfuric-acid", 5) },
  results = { item("processing-unit", 1) } }

-- Low density structure (2.5.4): 2 steel + 20 copper + 5 plastic -> 1 in 15 s (vanilla);
-- speed 3 = 0.2/s = 4 assemblers 2 = 600 kW.
local lds_recipe = { energy_required = 15,
  ingredients = { item("steel-plate", 2), item("copper-plate", 20), item("plastic-bar", 5) },
  results = { item("low-density-structure", 1) } }

-- Blue science (2.5.5): 2 engines (2 steel + 2 gears + 4 pipes = 2 steel + 8 iron) +
-- 3 advanced circuits + 1 sulfur -> 2 packs in 24 s; speed 2.4 = 0.2 packs/s = 3.2
-- assemblers 2 + 2.67 for engines + ~0.5 for gears and pipes = ~0.96 MW.
local blue_recipe = { energy_required = 24,
  ingredients = { item("steel-plate", 2), item("iron-plate", 8), item("advanced-circuit", 3), item("sulfur", 1) },
  results = { item("chemical-science-pack", 2) } }

-- Uranium (2.6.3): vanilla centrifuging without Kovarex (10 ore -> 0.7% U-235) and fuel
-- cells (10 iron + 1 U-235 + 19 U-238 -> 10 cells): ~143 ore + 1 iron per cell; spare
-- U-238 stays inside. Speed 1 = 0.01 cells/s from 1.43 ore/s = 1.7 centrifuges (350 kW)
-- + a sliver of an assembler = ~600 kW. One tier 1 city fuels a tier 3 nuclear city.
local uranium_recipe = { energy_required = 100,
  ingredients = { item("uranium-ore", 143), item("iron-plate", 1) },
  results = { item("uranium-fuel-cell", 1) } }

-- Nuclear power (2.6.4): uranium fuel cells burn in the city's burner (8 GJ each) while it
-- turns water into 500 C steam for a hidden generator, like reactor + heat exchangers +
-- turbines. 20 MW at T1 = 206.2 steam/s (vanilla's 2 heat exchangers) and 1 cell per
-- 400 s. It runs flat out like a vanilla reactor (playtest 2.6.6, user): unused steam is
-- vented by scripts/nuclear.lua so it keeps burning. No depleted cells (user): the fuel
-- cell's burnt result is removed.
local NUCLEAR_W = 20e6
local nuclear_steam_per_s = NUCLEAR_W / M.steam_joules(M.NUCLEAR_STEAM_TEMP)
local nuclear_recipe = { energy_required = 1,
  ingredients = { fluid("water", 100) },
  results = { { type = "fluid", name = "steam", amount = 100, temperature = M.NUCLEAR_STEAM_TEMP } } }
local function nuclear_tier(f, tier_cost)
  return { crafting_speed = nuclear_steam_per_s / 100 * f, recipe = nuclear_recipe,
    burner_power = string.format("%gMW", NUCLEAR_W / 1e6 * f),
    generator_usage = nuclear_steam_per_s / 60 * f, cost = tier_cost }
end

--- A depot-type city making a locomotive fuel (service port, 2.3.3); light oil in at the
--- middle of the south side.
local function fuel_depot(name, graphics, map_color, power_t1, recipe, speed_t1)
  local function kw(f) return string.format("%gkW", power_t1 * f) end
  return {
    name = name,
    service = true,
    graphics = { type = "assembling-machine", name = graphics },
    map_color = map_color,
    fluid_boxes = {
      { production_type = "input", position = { 0, 4 }, direction = defines.direction.south, filter = "light-oil" },
    },
    tiers = {
      { crafting_speed = speed_t1, power = kw(1), recipe = recipe },
      { crafting_speed = speed_t1 * 2, power = kw(2), recipe = recipe, cost = both_plates(1000) },
      { crafting_speed = speed_t1 * 4, power = kw(4), recipe = recipe, cost = with_circuits(2000, 1000) },
    },
  }
end

M.list = {
  smelting("iron-smelting", "iron-ore", "iron-plate", "copper-plate", { r = 0.55, g = 0.6, b = 0.7 }),
  smelting("copper-smelting", "copper-ore", "copper-plate", "iron-plate", { r = 0.8, g = 0.45, b = 0.25 }),
  {
    -- Counts as chemical plants (210 kW, 0.5 fuel/s each): 2 fuel/s = 840 kW at T1.
    name = "depot",
    service = true, -- has a service port for repairing locomotives (2.3.3)
    graphics = { type = "assembling-machine", name = "assembling-machine-3" },
    map_color = { r = 0.3, g = 0.3, b = 0.3 },
    tiers = {
      { crafting_speed = 2, power = "840kW", recipe = depot_recipe },
      { crafting_speed = 4, power = "1.68MW", recipe = depot_recipe, cost = both_plates(1000) },
      { crafting_speed = 8, power = "3.36MW", recipe = depot_recipe, cost = with_circuits(2000, 1000) },
    },
  },
  {
    -- Coal + water -> steam into a hidden generator. 150 steam per craft; the generator burns
    -- `generator_usage` steam per tick: 3 = 180/s = 5.4 MW, 6 = 10.8 MW, 12 = 21.6 MW.
    name = "power",
    graphics = { type = "assembling-machine", name = "centrifuge" }, -- 2.4.3: the refinery city took the oil refinery look
    map_color = { r = 0.9, g = 0.85, b = 0.3 },
    fluid_boxes = {
      { production_type = "input", position = { 0, 4 }, direction = defines.direction.south, filter = "water" },
      { production_type = "output", linked_id = 1, filter = "steam" },
    },
    tiers = {
      { crafting_speed = 1.2, recipe = power_recipe, generator_usage = 3 },
      { crafting_speed = 2.4, recipe = power_recipe, generator_usage = 6, cost = both_plates(1000) },
      { crafting_speed = 4.8, recipe = power_recipe, generator_usage = 12, cost = with_circuits(2000, 1000) },
    },
  },
  {
    name = "nuclear-power",
    graphics = { type = "reactor", name = "nuclear-reactor" },
    map_color = { r = 0.35, g = 0.85, b = 0.3 },
    generator = "tt-nuclear-generator",
    steam_temp = M.NUCLEAR_STEAM_TEMP,
    burner = { fuel_categories = { "nuclear" }, fuel = "uranium-fuel-cell" },
    fluid_boxes = {
      { production_type = "input", position = { 0, 4 }, direction = defines.direction.south, filter = "water" },
      -- room for the steam of a tier 3 city between vents (scripts/nuclear.lua)
      { production_type = "output", linked_id = 1, filter = "steam", volume = 4000 },
    },
    tiers = {
      nuclear_tier(1),
      nuclear_tier(2, with_circuits(2000, 1000)),
      nuclear_tier(4, with_circuits(4000, 2000)),
    },
  },
  assembler_city("circuits", { type = "assembling-machine", name = "electromagnetic-plant" },
    { r = 0.3, g = 0.7, b = 0.35 }, 1250, circuit_recipe, 0.5, both_plates(3000)),
  assembler_city("red-science", { type = "assembling-machine", name = "assembling-machine-1" },
    { r = 0.85, g = 0.25, b = 0.25 }, 1100, red_recipe, 1, with_circuits(2000, 1000)),
  assembler_city("green-science", { type = "assembling-machine", name = "assembling-machine-2" },
    { r = 0.35, g = 0.85, b = 0.35 }, 1500, green_recipe, 1, with_circuits(2000, 1000)),
  assembler_city("repair-packs", { type = "assembling-machine", name = "foundry" },
    { r = 0.75, g = 0.55, b = 0.85 }, 150, repair_recipe, 0.5, with_circuits(2000, 1000)),
  {
    -- Inputs on the south side, outputs on the north side, 2 tiles either side of the middle.
    name = "refinery",
    graphics = { type = "assembling-machine", name = "oil-refinery" },
    map_color = { r = 0.45, g = 0.35, b = 0.25 },
    fluid_boxes = {
      { production_type = "input", position = { -2, 4 }, direction = defines.direction.south, filter = "crude-oil" },
      { production_type = "input", position = { 2, 4 }, direction = defines.direction.south, filter = "water" },
      { production_type = "output", position = { -2, -4 }, direction = defines.direction.north, filter = "light-oil" },
      { production_type = "output", position = { 2, -4 }, direction = defines.direction.north, filter = "petroleum-gas" },
    },
    tiers = {
      { crafting_speed = 2, power = "950kW", recipe = refinery_recipe },
      { crafting_speed = 4, power = "1.9MW", recipe = refinery_recipe, cost = both_plates(1000) },
      { crafting_speed = 8, power = "3.8MW", recipe = refinery_recipe, cost = with_circuits(2000, 1000) },
    },
  },
  assembler_city("steel", { type = "furnace", name = "steel-furnace" },
    { r = 0.6, g = 0.62, b = 0.65 }, 1440, steel_recipe, 16, with_circuits(2000, 1000)),
  assembler_city("plastic", { type = "assembling-machine", name = "biochamber" },
    { r = 0.85, g = 0.85, b = 0.85 }, 315, plastic_recipe, 1.5, with_circuits(2000, 1000),
    { pipe_in(0, "petroleum-gas") }),
  assembler_city("sulfur", { type = "assembling-machine", name = "chemical-plant" },
    { r = 0.9, g = 0.85, b = 0.2 }, 105, sulfur_recipe, 0.5, with_circuits(2000, 1000),
    { pipe_in(-2, "petroleum-gas"), pipe_in(2, "water") }),
  assembler_city("sulfuric-acid", { type = "assembling-machine", name = "chemical-plant" },
    { r = 0.7, g = 0.9, b = 0.3 }, 100, acid_recipe, 0.1, with_circuits(2000, 1000),
    { pipe_in(0, "water"), pipe_out(0, "sulfuric-acid") }),
  assembler_city("advanced-circuits", { type = "assembling-machine", name = "assembling-machine-3" },
    { r = 0.85, g = 0.3, b = 0.3 }, 1350, advanced_recipe, 6, with_circuits(2000, 1000)),
  assembler_city("processing-units", { type = "assembling-machine", name = "electromagnetic-plant" },
    { r = 0.3, g = 0.4, b = 0.9 }, 400, processing_recipe, 2, with_circuits(2000, 1000),
    { pipe_in(0, "sulfuric-acid") }),
  assembler_city("low-density-structure", { type = "assembling-machine", name = "foundry" },
    { r = 0.75, g = 0.6, b = 0.45 }, 600, lds_recipe, 3, with_circuits(2000, 1000)),
  assembler_city("blue-science", { type = "assembling-machine", name = "assembling-machine-2" },
    { r = 0.3, g = 0.55, b = 0.95 }, 960, blue_recipe, 2.4, with_circuits(2000, 1000)),
  assembler_city("uranium", { type = "assembling-machine", name = "centrifuge" },
    { r = 0.4, g = 0.9, b = 0.3 }, 600, uranium_recipe, 1, with_circuits(2000, 1000)),
  fuel_depot("solid-fuel-depot", "chemical-plant", { r = 0.55, g = 0.45, b = 0.4 }, 420, solid_fuel_recipe, 2),
  fuel_depot("rocket-fuel-depot", "cryogenic-plant", { r = 0.9, g = 0.4, b = 0.2 }, 600, rocket_fuel_recipe, 3),
  {
    -- Rocket silo (PLAN 2.5.6): the vanilla silo with its own rocket part recipe at the
    -- base-game amounts (user): 10 processing units + 10 low density structures + 10
    -- rocket fuel per part, 3 s; 50 parts per rocket = 500 of each. (Space Age's part is
    -- 1 + 1 + 1.) One tier: an upgrade would replace the entity and lose the parts built.
    name = "rocket-silo",
    kind = "silo",
    parts = 50,
    map_color = { r = 0.95, g = 0.95, b = 0.95 },
    tiers = { { power = "250kW", recipe = { energy_required = 3,
      ingredients = { item("processing-unit", 10), item("low-density-structure", 10), item("rocket-fuel", 10) },
      results = { item("rocket-part", 1) } } } },
  },
  {
    -- Research complex (PLAN 2.2.3): a lab prototype; the engine runs research. Tier 1 =
    -- 20 labs (speed 1, 60 kW each). Its "product" is research, so any items may pay.
    name = "research",
    kind = "lab",
    graphics = { type = "lab", name = "lab" },
    map_color = { r = 0.4, g = 0.6, b = 0.95 },
    inputs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack" }, -- blue: 2.5.5
    tiers = {
      { researching_speed = 20, power = "1200kW" },
      { researching_speed = 40, power = "2400kW", cost = with_circuits(1000, 500) },
      { researching_speed = 80, power = "4800kW", cost = with_circuits(3000, 2000) },
    },
  },
}

---@param name string city definition name, e.g. "iron-smelting"
---@param tier integer
function M.entity_name(name, tier)
  return tier == 1 and (M.PREFIX .. name) or (M.PREFIX .. name .. "-t" .. tier)
end

--- Hidden generator of a power city tier (tier 1 keeps the MVP name). Cities with their
--- own generator (`def.generator`, the nuclear city) use that as the base name.
---@param tier integer
---@param def table? city definition (default: the coal power city)
function M.generator_name(tier, def)
  local base = def and def.generator or "tt-power-generator"
  return tier == 1 and base or (base .. "-t" .. tier)
end

-- entity name -> { def = city definition, tier = n, max_tier = n }
M.by_entity = {}
for _, def in ipairs(M.list) do
  for tier in ipairs(def.tiers) do
    M.by_entity[M.entity_name(def.name, tier)] = { def = def, tier = tier, max_tier = #def.tiers }
  end
end

--- Everything a city consumes (any tier): recipe ingredients, burner fuel, lab inputs.
---@return string[]
local function inputs_of(def)
  local names, seen = {}, {}
  local function add(n) if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  for _, tier in ipairs(def.tiers) do
    for _, ing in ipairs(tier.recipe and tier.recipe.ingredients or {}) do add(ing.name) end
  end
  if def.burner then add(def.burner.fuel) end
  for _, n in ipairs(def.inputs or {}) do add(n) end
  return names
end

-- product name -> city definitions that make it
local producers = {}
for _, def in ipairs(M.list) do
  for _, tier in ipairs(def.tiers) do
    for _, r in ipairs(tier.recipe and tier.recipe.results or {}) do
      producers[r.name] = producers[r.name] or {}
      producers[r.name][def.name] = def
    end
  end
end

--- Chain depth of every city definition (2.8.1): a city is one deeper than its deepest
--- input, and an input no city makes (ore, coal, water, crude oil) is depth 0. Several
--- producers of one input: the shallowest counts. Worked out from the recipes, so a new
--- city type gets its depth for free. def name -> depth (1 = fed by raw resources only).
M.depth = {}
do
  local visiting = {}
  local function depth_of(def)
    if M.depth[def.name] then return M.depth[def.name] end
    if visiting[def.name] then return 0 end -- a loop: don't count it
    visiting[def.name] = true
    local deepest = 0
    for _, input in ipairs(inputs_of(def)) do
      local best
      for _, p in pairs(producers[input] or {}) do
        if p ~= def then
          local d = depth_of(p)
          if not best or d < best then best = d end
        end
      end
      deepest = math.max(deepest, best or 0)
    end
    visiting[def.name] = nil
    M.depth[def.name] = deepest + 1
    return deepest + 1
  end
  for _, def in ipairs(M.list) do depth_of(def) end
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
