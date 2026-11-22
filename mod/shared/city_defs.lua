-- City definitions. Plain data, read by both stages: the data stage (prototypes/cities.lua)
-- builds one entity per city kind, the control stage reads names, rates and recipes.
-- Rates are tuning values; see DECISIONS.md.
--
-- Entity names are "tt-city-<name>". Since 2.15 the player builds cities on plots and
-- cities have no tiers: more output means another city. A kind that is a later version of
-- another (electric smelting after coal-fired) names it in `upgrade_from`: the upgrade
-- planner swaps one for the other in place.
local M = {}

M.PREFIX = "tt-city-"
-- Both power cities make 500 C steam, 97 kJ/unit (0.2 kJ/C above 15 C), as from vanilla
-- heat exchangers (2.6.4). The coal power city made 165 C steam (30 kJ) until playtest
-- 2.15.10, when it went to 20 MW on one water city's output (user).
M.POWER_STEAM_TEMP = 500
M.NUCLEAR_STEAM_TEMP = 500

--- Energy in one unit of steam at `temp` C (water heat capacity 0.2 kJ/C, from 15 C).
---@param temp number
function M.steam_joules(temp) return (temp - 15) * 200 end

local function item(name, amount) return { type = "item", name = name, amount = amount } end

--- A smelting city: coal-fired (`electric` false: coal is an ingredient, burnt as fuel) or
--- electric (no coal; the electric furnaces' power). 10 plates per craft of 1 s.
local function smelting(name, ore, plate, map_color, electric)
  local ingredients = { item(ore, 10) }
  if not electric then ingredients[#ingredients + 1] = item("coal", 1) end
  return {
    name = electric and ("electric-" .. name) or name,
    upgrade_from = electric and name or nil,
    full_rate = true, -- 15 plates/s, not halved (user, playtest 2.15.10: iron was the bottleneck)
    graphics = { type = "furnace", name = "electric-furnace" },
    map_color = map_color,
    -- 10 plates/s at speed 1.5 = 15 plates/s (900/min, one yellow belt). Electric furnace
    -- = 0.625 plates/s at 180 kW, so 15 plates/s = 24 furnaces = 4.32 MW.
    crafting_speed = 1.5,
    power = electric and "4.32MW" or nil,
    recipe = { energy_required = 1, ingredients = ingredients, results = { item(plate, 10) } },
  }
end

local depot_recipe = { energy_required = 1, ingredients = { item("coal", 2) }, results = { item("tt-coal-fuel", 1) } }

-- Coal power (user, playtest 2.15.10): 20 MW, not halved (the rate cut left 2.7 MW, about
-- one electric smelting city). Coal at vanilla's 4 MJ: 5 coal/s. One water city's 300/s
-- feeds it: 500 C steam, 206.2 water/s (vanilla 165 C steam would need 667/s).
M.COAL_POWER_W = 20e6
local coal_steam_per_s = M.COAL_POWER_W / M.steam_joules(M.POWER_STEAM_TEMP)
local power_recipe = {
  energy_required = 1,
  ingredients = { item("coal", 5), { type = "fluid", name = "water", amount = coal_steam_per_s } },
  results = { { type = "fluid", name = "steam", amount = coal_steam_per_s, temperature = M.POWER_STEAM_TEMP } },
}

-- Intermediate cities (PLAN 2.2.2). Power = the vanilla assembling machine 2s (speed 0.75,
-- 150 kW) that would make the same output; gears and cables are made inside the city.
local function assembler_city(name, graphics, map_color, power_kw, recipe, speed, fluid_boxes)
  return {
    name = name,
    graphics = graphics,
    map_color = map_color,
    fluid_boxes = fluid_boxes,
    crafting_speed = speed,
    power = string.format("%gkW", power_kw),
    recipe = recipe,
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
-- (speed 2, 180 kW each): 1 steel/s from 5 iron/s, 1.44 MW.
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

-- Fluid connections: where they sit comes from shared/port_layout.lua (2.10).
local function pipe_in(f) return { production_type = "input", filter = f } end
local function pipe_out(f) return { production_type = "output", filter = f } end

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
-- + a sliver of an assembler = ~600 kW. One city fuels about four nuclear cities.
local uranium_recipe = { energy_required = 100,
  ingredients = { item("uranium-ore", 143), item("iron-plate", 1) },
  results = { item("uranium-fuel-cell", 1) } }

-- Nuclear power (2.6.4): uranium fuel cells burn in the city's burner (8 GJ each) while it
-- turns water into 500 C steam for a hidden generator, like reactor + heat exchangers +
-- turbines. 20 MW at T1 = 206.2 steam/s (vanilla's 2 heat exchangers) and 1 cell per
-- 400 s. Since playtest 2.15.10 (user) 100 MW, not halved: 1031 water/s (a few water
-- cities) and a cell per 80 s. It runs flat out like a vanilla reactor (playtest 2.6.6, user): unused steam is
-- vented by scripts/nuclear.lua so it keeps burning. No depleted cells (user): the fuel
-- cell's burnt result is removed.
local NUCLEAR_W = 100e6
local nuclear_steam_per_s = NUCLEAR_W / M.steam_joules(M.NUCLEAR_STEAM_TEMP)
local nuclear_recipe = { energy_required = 1,
  ingredients = { fluid("water", 100) },
  results = { { type = "fluid", name = "steam", amount = 100, temperature = M.NUCLEAR_STEAM_TEMP } } }

-- Water (2.9.1): the only source of water (offshore pumps are removed). No inputs and no
-- power: the vanilla offshore pump draws none in 2.x. 600 water per craft of 1 s.
M.WATER_PER_S = 600
local water_recipe = { energy_required = 1, ingredients = {}, results = { fluid("water", M.WATER_PER_S) } }

--- A depot-type city making a locomotive fuel (service port, 2.3.3); light oil in.
local function fuel_depot(name, graphics, map_color, power_kw, recipe, speed)
  return {
    name = name,
    service = true,
    graphics = { type = "assembling-machine", name = graphics },
    map_color = map_color,
    fluid_boxes = {
      pipe_in("light-oil"),
    },
    crafting_speed = speed,
    power = string.format("%gkW", power_kw),
    recipe = recipe,
  }
end

M.list = {
  smelting("iron-smelting", "iron-ore", "iron-plate", { r = 0.55, g = 0.6, b = 0.7 }),
  smelting("copper-smelting", "copper-ore", "copper-plate", { r = 0.8, g = 0.45, b = 0.25 }),
  smelting("iron-smelting", "iron-ore", "iron-plate", { r = 0.55, g = 0.6, b = 0.7 }, true),
  smelting("copper-smelting", "copper-ore", "copper-plate", { r = 0.8, g = 0.45, b = 0.25 }, true),
  {
    -- Counts as chemical plants (210 kW, 0.5 fuel/s each): 2 fuel/s = 840 kW at T1.
    name = "depot",
    service = true, -- has a service port for repairing locomotives (2.3.3)
    graphics = { type = "assembling-machine", name = "assembling-machine-3" },
    map_color = { r = 0.3, g = 0.3, b = 0.3 },
    crafting_speed = 2, power = "840kW", recipe = depot_recipe,
  },
  {
    -- Coal + water -> steam into a hidden generator, which burns `generator_usage` steam
    -- per tick: 206.2/s = 20 MW. Not halved (full_rate).
    name = "power",
    full_rate = true,
    roof_icon = "item/steam-engine", -- 2.10: painted on the roof (default: the first product)
    graphics = { type = "assembling-machine", name = "centrifuge" }, -- 2.4.3: the refinery city took the oil refinery look
    map_color = { r = 0.9, g = 0.85, b = 0.3 },
    fluid_boxes = {
      pipe_in("water"),
      { production_type = "output", linked_id = 1, filter = "steam" },
    },
    crafting_speed = 1, recipe = power_recipe, generator_usage = coal_steam_per_s / 60,
  },
  {
    name = "nuclear-power",
    roof_icon = "item/nuclear-reactor",
    graphics = { type = "reactor", name = "nuclear-reactor" },
    map_color = { r = 0.35, g = 0.85, b = 0.3 },
    generator = "tt-nuclear-generator",
    full_rate = true, -- 100 MW, not halved (user, playtest 2.15.10)
    steam_temp = M.NUCLEAR_STEAM_TEMP,
    burner = { fuel_categories = { "nuclear" }, fuel = "uranium-fuel-cell" },
    fluid_boxes = {
      pipe_in("water"),
      -- room for more steam than it makes between vents (scripts/nuclear.lua)
      { production_type = "output", linked_id = 1, filter = "steam", volume = 4000 },
    },
    crafting_speed = nuclear_steam_per_s / 100, recipe = nuclear_recipe,
    burner_power = string.format("%gMW", NUCLEAR_W / 1e6),
    generator_usage = nuclear_steam_per_s / 60,
  },
  {
    -- Room for two crafts.
    name = "water",
    graphics = { type = "mining-drill", name = "pumpjack" },
    map_color = { r = 0.25, g = 0.5, b = 0.9 },
    fluid_boxes = {
      { production_type = "output", filter = "water",
        volume = 2 * M.WATER_PER_S },
    },
    crafting_speed = 1, recipe = water_recipe,
  },
  assembler_city("circuits",{ type = "assembling-machine", name = "electromagnetic-plant" },
    { r = 0.3, g = 0.7, b = 0.35 }, 1250, circuit_recipe, 0.5),
  assembler_city("red-science", { type = "assembling-machine", name = "assembling-machine-1" },
    { r = 0.85, g = 0.25, b = 0.25 }, 1100, red_recipe, 1),
  assembler_city("green-science", { type = "assembling-machine", name = "assembling-machine-2" },
    { r = 0.35, g = 0.85, b = 0.35 }, 1500, green_recipe, 1),
  assembler_city("repair-packs", { type = "assembling-machine", name = "foundry" },
    { r = 0.75, g = 0.55, b = 0.85 }, 150, repair_recipe, 0.5),
  {
    name = "refinery",
    graphics = { type = "assembling-machine", name = "oil-refinery" },
    map_color = { r = 0.45, g = 0.35, b = 0.25 },
    fluid_boxes = {
      pipe_in("crude-oil"),
      pipe_in("water"),
      pipe_out("light-oil"),
      pipe_out("petroleum-gas"),
    },
    crafting_speed = 2, power = "950kW", recipe = refinery_recipe,
  },
  assembler_city("steel", { type = "furnace", name = "steel-furnace" },
    { r = 0.6, g = 0.62, b = 0.65 }, 1440, steel_recipe, 16),
  assembler_city("plastic", { type = "assembling-machine", name = "biochamber" },
    { r = 0.85, g = 0.85, b = 0.85 }, 315, plastic_recipe, 1.5,
    { pipe_in("petroleum-gas") }),
  assembler_city("sulfur", { type = "assembling-machine", name = "chemical-plant" },
    { r = 0.9, g = 0.85, b = 0.2 }, 105, sulfur_recipe, 0.5,
    { pipe_in("petroleum-gas"), pipe_in("water") }),
  assembler_city("sulfuric-acid", { type = "assembling-machine", name = "chemical-plant" },
    { r = 0.7, g = 0.9, b = 0.3 }, 100, acid_recipe, 0.1,
    { pipe_in("water"), pipe_out("sulfuric-acid") }),
  assembler_city("advanced-circuits", { type = "assembling-machine", name = "assembling-machine-3" },
    { r = 0.85, g = 0.3, b = 0.3 }, 1350, advanced_recipe, 6),
  assembler_city("processing-units", { type = "assembling-machine", name = "electromagnetic-plant" },
    { r = 0.3, g = 0.4, b = 0.9 }, 400, processing_recipe, 2,
    { pipe_in("sulfuric-acid") }),
  assembler_city("low-density-structure", { type = "assembling-machine", name = "foundry" },
    { r = 0.75, g = 0.6, b = 0.45 }, 600, lds_recipe, 3),
  assembler_city("blue-science", { type = "assembling-machine", name = "assembling-machine-2" },
    { r = 0.3, g = 0.55, b = 0.95 }, 960, blue_recipe, 2.4),
  assembler_city("uranium", { type = "assembling-machine", name = "centrifuge" },
    { r = 0.4, g = 0.9, b = 0.3 }, 600, uranium_recipe, 1),
  fuel_depot("solid-fuel-depot", "chemical-plant", { r = 0.55, g = 0.45, b = 0.4 }, 420, solid_fuel_recipe, 2),
  fuel_depot("rocket-fuel-depot", "cryogenic-plant", { r = 0.9, g = 0.4, b = 0.2 }, 600, rocket_fuel_recipe, 3),
  {
    -- Rocket silo (PLAN 2.5.6): the vanilla silo with its own rocket part recipe at the
    -- base-game amounts (user): 10 processing units + 10 low density structures + 10
    -- rocket fuel per part, 3 s; 50 parts per rocket = 500 of each. (Space Age's part is
    -- 1 + 1 + 1.)
    name = "rocket-silo",
    kind = "silo",
    parts = 50,
    map_color = { r = 0.95, g = 0.95, b = 0.95 },
    power = "250kW",
    recipe = { energy_required = 3,
      ingredients = { item("processing-unit", 10), item("low-density-structure", 10), item("rocket-fuel", 10) },
      results = { item("rocket-part", 1) } },
  },
  {
    -- Research complex (PLAN 2.2.3): a lab prototype; the engine runs research. 20 labs
    -- (speed 1, 60 kW each).
    name = "research",
    roof_icon = "item/lab",
    kind = "lab",
    graphics = { type = "lab", name = "lab" },
    map_color = { r = 0.4, g = 0.6, b = 0.95 },
    inputs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack" }, -- blue: 2.5.5
    researching_speed = 20, power = "1200kW",
  },
}

-- 2.15.7 (user, phase 2.15): every city runs at half the rates worked out above, so a
-- product needs several cities ("my steel is maxed out, I need another steel city"). The
-- derivations above stay as written (full rates); speed, power, steam and research speed
-- are all scaled here. The rocket silo keeps its rate: its output is the win, not a flow.
-- Power cities (`full_rate`) keep theirs too, raised in playtest 2.15.10 (user).
M.RATE = 0.5
do
  local function power(str)
    if not str then return nil end
    local n, unit = string.match(str, "^([%d%.]+)(%a+)$")
    return string.format("%g%s", tonumber(n) * M.RATE, unit)
  end
  for _, def in ipairs(M.list) do
    if def.kind ~= "silo" and not def.full_rate then
      if def.crafting_speed then def.crafting_speed = def.crafting_speed * M.RATE end
      if def.researching_speed then def.researching_speed = def.researching_speed * M.RATE end
      if def.generator_usage then def.generator_usage = def.generator_usage * M.RATE end
      def.power = power(def.power)
      def.burner_power = power(def.burner_power)
    end
  end
end

-- The technology that unlocks building each city kind (2.15.5, agreed with the user
-- 2026-11-21): the vanilla technology for the same thing. Kinds not listed are there from
-- the start: depot, coal power, water, iron and copper smelting, red science, the research
-- complex and circuits (Electronics is a starting technology).
M.UNLOCK = {
  ["repair-packs"] = "repair-pack",
  ["steel"] = "steel-processing",
  ["green-science"] = "logistic-science-pack",
  ["electric-iron-smelting"] = "advanced-material-processing",
  ["electric-copper-smelting"] = "advanced-material-processing",
  ["refinery"] = "oil-processing",
  ["solid-fuel-depot"] = "oil-processing",
  ["plastic"] = "plastics",
  ["sulfur"] = "sulfur-processing",
  ["sulfuric-acid"] = "sulfur-processing",
  ["advanced-circuits"] = "advanced-circuit",
  ["blue-science"] = "chemical-science-pack",
  ["processing-units"] = "processing-unit",
  ["low-density-structure"] = "low-density-structure",
  ["rocket-fuel-depot"] = "rocket-fuel",
  ["uranium"] = "uranium-processing",
  ["nuclear-power"] = "nuclear-power",
  ["rocket-silo"] = "rocket-silo",
}
for _, def in ipairs(M.list) do def.unlock = M.UNLOCK[def.name] end

---@param name string city definition name, e.g. "iron-smelting"
function M.entity_name(name) return M.PREFIX .. name end

--- Hidden generator of a power city: `def.generator` (the nuclear city) or the coal power
--- city's.
---@param def table? city definition (default: the coal power city)
function M.generator_name(def) return def and def.generator or "tt-power-generator" end

-- entity name -> { def = city definition }
M.by_entity = {}
for _, def in ipairs(M.list) do M.by_entity[M.entity_name(def.name)] = { def = def } end

--- Everything a city consumes: recipe ingredients, burner fuel, lab inputs.
---@return string[]
local function inputs_of(def)
  local names, seen = {}, {}
  local function add(n) if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  for _, ing in ipairs(def.recipe and def.recipe.ingredients or {}) do add(ing.name) end
  if def.burner then add(def.burner.fuel) end
  for _, n in ipairs(def.inputs or {}) do add(n) end
  return names
end

-- product name -> city definitions that make it
local producers = {}
for _, def in ipairs(M.list) do
  for _, r in ipairs(def.recipe and def.recipe.results or {}) do
    producers[r.name] = producers[r.name] or {}
    producers[r.name][def.name] = def
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

--- Does this city entity feed a hidden generator (a power city)?
---@param entity_name string
function M.is_power(entity_name)
  local info = M.by_entity[entity_name]
  return info ~= nil and info.def.generator_usage ~= nil
end

return M
