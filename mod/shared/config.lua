-- Game rules shared by the data and control stages. Plain data only.
local M = {}

-- Recipe category of the free logistics recipes; the only category the character can craft.
M.FREE_CATEGORY = "tt-free"
-- Craft time of free recipes. The engine requires > 0.001 s; this crafts ~1 item per tick.
M.FREE_CRAFT_TIME = 0.002

-- The only fuel category locomotives burn. tt-coal-fuel (depot cities) is in it.
M.LOCOMOTIVE_FUEL_CATEGORY = "tt-locomotive"
-- Items in that category (2.4.1): coal fuel (depot), solid fuel and rocket fuel (fuel depots).
M.LOCOMOTIVE_FUELS = { "tt-coal-fuel", "solid-fuel", "rocket-fuel" }

-- Limp mode: hidden reserve fuel burned by fuel-empty locomotives (DECISIONS.md A3, 1.7).
M.LIMP_FUEL = "tt-limp-fuel"
M.LIMP_FUEL_VALUE = "100GJ"         -- effectively never runs out; re-applied if it does
M.LIMP_FUEL_JOULES = 100e9
M.LIMP_TOP_SPEED = 0.25             -- x locomotive max speed (1.2 -> 0.3 tiles/tick, ~65 km/h); 0.10 crawled with wagons (playtest 2.3.5)
M.LIMP_ACCELERATION = 0.6
-- Every LIMP_INTERVAL ticks a slice of locomotives is checked so each one is seen about
-- once per LIMP_PASS_TICKS.
M.LIMP_INTERVAL = 10
M.LIMP_PASS_TICKS = 60

-- Reliability (PLAN 2.3): a locomotive's health. Driving drains it; the poll above applies
-- the wear for the time since the locomotive was last seen, if it is moving.
-- Fraction of max health lost per minute of driving, per locomotive prototype (tiers later).
M.RELIABILITY_DECAY_PER_MINUTE = { locomotive = 0.075, ["tt-locomotive-2"] = 0.05, ["tt-locomotive-3"] = 0.03 }

-- Locomotive tiers (PLAN 2.11, user 2026-11-21). Tier 1 is the vanilla locomotive (600 kW,
-- 1.2 tiles/tick = 259 km/h, effectivity 1). Speeds in tiles per tick (x 216 = km/h).
M.LOCOMOTIVE_TIER_NAME = { [2] = "tt-locomotive-2", [3] = "tt-locomotive-3" }
M.LOCOMOTIVE_TIERS = {
  [2] = { max_power = "900kW", max_speed = 290 / 216, effectivity = 1.25,
    color = { r = 0.1, g = 0.45, b = 0.9, a = 0.5 },
    prerequisites = { "railway", "logistic-science-pack" }, research_count = 200,
    research = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } } },
  [3] = { max_power = "1.2MW", max_speed = 324 / 216, effectivity = 1.5,
    color = { r = 0.6, g = 0.25, b = 0.85, a = 0.5 },
    prerequisites = { "tt-locomotive-2", "advanced-circuit", "chemical-science-pack" }, research_count = 300,
    research = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 } } },
}
M.RELIABILITY_FLOOR = 0.10 -- wear never takes a locomotive below this fraction
-- While moving, chance per second of a breakdown = BREAKDOWN_CHANCE x (1 - health)^2.
M.BREAKDOWN_CHANCE = 0.02

-- City entity names (prototypes/cities.lua).
M.CITY = {
  iron = "tt-city-iron-smelting",
  copper = "tt-city-copper-smelting",
  depot = "tt-city-depot",
  power = "tt-city-power",
  goal = "tt-city-goal",
}

-- Goal box: slots 1..GOAL_SLOTS/2 take iron plates, the rest copper plates.
M.GOAL_SLOTS = 40
M.GOAL_ITEMS = { iron = "iron-plate", copper = "copper-plate" }
-- Filter used for a metal whose target is met: the goal box stops accepting it.
M.GOAL_CLOSED_ITEM = "tt-goal-closed"

-- Construction port beside each upgradable city (PLAN 2.1.2).
-- Plots (2.15.3): the tiles a city must stand on, and their collision layer.
M.PLOT_TILE = "tt-plot"
M.PLOT_BORDER_TILE = "tt-plot-border"
M.PLOT_LAYER = "tt_plot"
M.CITY_SUBGROUP = "tt-cities"
M.CITY_BUILD_RECIPE_PREFIX = "tt-build-" -- recipe "tt-build-<city entity name>" crafts its item
M.BELT_PORT = "tt-belt-port" -- 2.10.4: hidden loader under a city wall
M.SERVICE_BOX_PORT = "tt-belt-port-service" -- 2.10.14: the same for a depot's repair packs
M.SIGNAL_POINT = "tt-signal-point" -- 2.11: a city's stock and status, for the circuit network
-- 2.15.10 (user, playtest): a hidden, unpowered radar in every city keeps its surroundings
-- live on the map, CITY_RADAR_CHUNKS chunks around it (2 = 5x5 chunks)
M.CITY_RADAR = "tt-hidden-radar"
M.CITY_RADAR_CHUNKS = 2
-- Throttle (2.12): a hidden beacon in each crafting city and the research complex, with
-- modules taking THROTTLE_STEP off speed and power each; at most THROTTLE_MAX_STEPS (the
-- engine floors speed and consumption at 20%).
M.THROTTLE_BEACON = "tt-throttle-beacon"
M.THROTTLE_MODULE = "tt-throttle-module"
M.THROTTLE_CATEGORY = "tt-throttle"
M.THROTTLE_STEP = 0.05
M.THROTTLE_MAX_STEPS = 16
M.SIGNAL = { -- 2.11: status signals of the stock point (value 1 while true)
  running = "tt-city-running", starved = "tt-city-starved",
  output_full = "tt-city-output-full", no_power = "tt-city-no-power",
  speed = "tt-city-speed", -- 2.12: its speed in percent
}

-- Service port beside each depot city (PLAN 2.3.3): takes repair packs only. Locomotives of
-- a train stopped at a train stop within SERVICE_RANGE tiles of the depot's edge are
-- repaired at SERVICE_HP_PER_SECOND each, using one pack per SERVICE_HP_PER_PACK.
M.SERVICE_PORT = "tt-service-port"
M.SERVICE_SLOTS = 4
M.SERVICE_ITEM = "repair-pack"
M.SERVICE_RANGE = 30
-- A train standing still with a locomotive this close to a stop in range is serviced too,
-- so manually driven trains count (automatic ones are found via get_stopped_train).
M.SERVICE_STOP_RADIUS = 10
M.SERVICE_HP_PER_SECOND = 100
M.SERVICE_HP_PER_PACK = 300 -- the vanilla repair pack's durability
-- How often the goal box is emptied and counted, and the rate window (for the UI).
M.GOAL_TICK_INTERVAL = 60
M.RATE_WINDOW_TICKS = 60 * 60

-- Hidden companion entities placed with a city and joined by a linked fluidbox connection.
-- city entity name -> { entity, city_link_id, companion_link_id }. One generator per power
-- city kind (shared/city_defs.lua).
local city_defs = require("shared.city_defs")
M.CITY_COMPANIONS = {}
for _, def in ipairs(city_defs.list) do
  if def.generator_usage then
    M.CITY_COMPANIONS[city_defs.entity_name(def.name)] = {
      entity = city_defs.generator_name(def), city_link_id = 1, companion_link_id = 1 }
  end
end

-- Free items (SPEC: train infrastructure, station logistics, extraction). Their recipes get
-- no ingredients and stay gated by their vanilla technology.
M.FREE_ITEMS = {
  -- rails and trains
  "rail", "rail-signal", "rail-chain-signal", "train-stop",
  "locomotive", "tt-locomotive-2", "tt-locomotive-3", "cargo-wagon", "fluid-wagon",
  -- personal construction robots (user, 2026-11-21): replace lost ones by hand
  "construction-robot",
  "rail-ramp", "rail-support",
  -- inserters
  "burner-inserter", "inserter", "long-handed-inserter", "fast-inserter", "bulk-inserter", "stack-inserter",
  -- belts
  "transport-belt", "underground-belt", "splitter",
  "fast-transport-belt", "fast-underground-belt", "fast-splitter",
  "express-transport-belt", "express-underground-belt", "express-splitter",
  "turbo-transport-belt", "turbo-underground-belt", "turbo-splitter",
  -- chests (not logistic)
  "wooden-chest", "iron-chest", "steel-chest",
  -- fluids
  "pipe", "pipe-to-ground", "pump", "storage-tank",
  -- power distribution
  "small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation",
  -- circuit entities
  "arithmetic-combinator", "decider-combinator", "constant-combinator", "selector-combinator",
  "power-switch", "programmable-speaker", "display-panel", "small-lamp",
  -- extraction
  "burner-mining-drill", "electric-mining-drill", "big-mining-drill", "pumpjack",
  -- map view (user, playtest 2.15.10): watch stations and mines from the map
  "radar",
}

-- Items the player must never get (SPEC: transformation happens in cities; transport is
-- trains only; no robots; no planets/platforms). Their recipes are hidden and disabled, and
-- technologies stop unlocking them.
M.BANNED_ITEMS = {
  -- transformation
  "stone-furnace", "steel-furnace", "electric-furnace",
  "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
  "oil-refinery", "chemical-plant", "centrifuge",
  "foundry", "electromagnetic-plant", "biochamber", "cryogenic-plant", "recycler", "crusher",
  "agricultural-tower", "captive-biter-spawner", "lab", "biolab", "rocket-silo", "beacon",
  -- power generation
  "boiler", "steam-engine", "steam-turbine", "solar-panel", "nuclear-reactor",
  "heat-exchanger", "heat-pipe", "heating-tower", "fusion-reactor", "fusion-generator",
  "lightning-collector", "lightning-rod",
  -- water: only water cities make it (2.9.2)
  "offshore-pump",
  -- vehicles
  "car", "tank", "spidertron",
  -- robots: personal construction robots are allowed (user, 2026-11-21: start kit,
  -- scripts/start_kit.lua); roboports on the ground and logistic robots stay out
  "logistic-robot", "roboport",
  "active-provider-chest", "passive-provider-chest", "storage-chest", "buffer-chest", "requester-chest",
  -- space
  "asteroid-collector", "thruster", "cargo-bay", "cargo-landing-pad", "space-platform-starter-pack",
}

-- Technologies hidden outright (planets and platforms are off).
-- (2.15.5: the Rocket silo technology stays visible: it unlocks the rocket silo city.)
M.HIDDEN_TECH_PATTERNS = { "^planet%-discovery%-", "^space%-platform" }

-- Researched for the player force at game start (SPEC MVP starting research).
M.START_TECHNOLOGIES = {
  -- Space Age roots the whole tree here, triggered by crafting a lab; the research complex
  -- takes the lab's place (2.2.3), so it starts researched.
  "automation-science-pack",
  "railway",                        -- rail, locomotive, cargo wagon
  "automated-rail-transportation",  -- train stop, rail and chain signals
  "fluid-wagon",
  "electronics",                    -- inserter, small electric pole
  "logistics",                      -- underground belt, splitter
  "electric-mining-drill",
  "steam-power",                    -- pipe, pipe-to-ground (boiler, engine and offshore pump stripped)
  "fluid-handling",                 -- pump, storage tank
  "electric-energy-distribution-1", -- medium and big electric pole
  "construction-robotics",          -- construction robot (free; personal robots, 2026-11-21)
}

-- What every new player starts wearing and carrying (user, 2026-11-21): personal
-- construction robots. Power armor (6x8 grid) holds the reactor (4x4, no fuel), two
-- roboports (2x2, 10 robots each) and two batteries (1x2).
-- Construction robots fly this many times the vanilla speed and use no energy (user,
-- 2026-11-21, like Speedy Bot Start).
M.ROBOT_SPEED_FACTOR = 5
M.START_KIT = {
  armor = "power-armor",
  equipment = {
    { name = "fission-reactor-equipment", count = 1 },
    { name = "personal-roboport-equipment", count = 2 },
    { name = "battery-equipment", count = 2 },
  },
  robots = 20,
}

local function set(list) local s = {} for _, v in ipairs(list) do s[v] = true end return s end
M.FREE_SET = set(M.FREE_ITEMS)
M.BANNED_SET = set(M.BANNED_ITEMS)

return M
