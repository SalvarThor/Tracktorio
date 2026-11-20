-- Black box ("city") prototype generator. Data stage only.
--
-- Every city is an assembling-machine with a fixed recipe and a void energy source, so the
-- engine provides "rate of the slowest input" and output backpressure. No item places it;
-- the control stage places it by script and protects it (scripts/cities.lua).
-- Entity names are "tt-city-<name>"; control code recognises cities by that prefix.
--
-- Definition fields:
--   name            string, suffix of the entity name
--   size            odd integer tile size (default 9)
--   graphics        { type = <prototype type>, name = <prototype name> } vanilla source,
--                   scaled up as a placeholder sprite
--   crafting_speed  number (tier cap)
--   recipe          { energy_required, ingredients, results } (2.1 ingredient/product format)
--   fluid_boxes     optional list of { production_type = "input"|"output",
--                   position = {x, y} (edge tile, relative to centre), direction = defines.direction.*,
--                   or linked_id = n for a hidden linked connection; optional filter, volume }
--   power           optional electric draw at full output, e.g. "840kW" (SPEC: cities whose
--                   vanilla equivalent is electric draw that power). Omitted = no power.
--   burner          optional { fuel_categories, power }: the city burns fuel put in by
--                   inserter at `power` while crafting (the nuclear city, 2.6.4).
--   map_color       optional color
--   extra           optional table merged into the entity prototype

local M = {}

M.PREFIX = "tt-city-"

--- Recursively scale every sprite definition found in a graphics table.
local function scale_sprites(t, factor)
  if type(t) ~= "table" then return end
  if t.filename or t.filenames or t.stripes then
    t.scale = (t.scale or 1) * factor
    if t.shift then t.shift = { t.shift[1] * factor, t.shift[2] * factor } end
  end
  for _, v in pairs(t) do
    if type(v) == "table" then scale_sprites(v, factor) end
  end
end

local function source_prototype(src)
  local p = data.raw[src.type] and data.raw[src.type][src.name]
  assert(p, "tt: city graphics source not found: " .. src.type .. "/" .. src.name)
  return p
end

local function make_fluid_boxes(defs, pipe_source)
  if not defs then return nil end
  local base = pipe_source.fluid_boxes and pipe_source.fluid_boxes[1]
  local boxes = {}
  for _, f in ipairs(defs) do
    local connection
    if f.linked_id then
      -- hidden link to a companion entity (e.g. the power city's generator)
      connection = { connection_type = "linked", linked_connection_id = f.linked_id, flow_direction = f.production_type }
    else
      connection = { flow_direction = f.production_type, direction = f.direction, position = f.position }
    end
    boxes[#boxes + 1] = {
      production_type = f.production_type,
      volume = f.volume or 1000,
      filter = f.filter,
      pipe_picture = (not f.linked_id and base) and table.deepcopy(base.pipe_picture) or nil,
      pipe_covers = (not f.linked_id and base) and table.deepcopy(base.pipe_covers) or nil,
      pipe_connections = { connection },
      secondary_draw_orders = { north = -1 },
    }
  end
  return boxes
end

--- Build the prototypes for one city. Returns a list for data:extend.
---@param def table
---@return table[]
function M.make_city(def)
  local name = M.PREFIX .. def.name
  local size = def.size or 9
  local half = size / 2
  local src = source_prototype(def.graphics)
  local src_size = math.max(1, math.floor(src.collision_box[2][1] - src.collision_box[1][1] + 0.6))
  local factor = size / src_size

  -- Sources without a graphics_set (the nuclear reactor) lend their static picture.
  local graphics_set = table.deepcopy(src.graphics_set or (src.picture and { animation = src.picture }))
  if graphics_set then
    graphics_set.frozen_patch = nil
    graphics_set.water_reflection = nil
    scale_sprites(graphics_set, factor)
  end

  local category = {
    type = "recipe-category",
    name = name,
  }

  local recipe = {
    type = "recipe",
    name = name,
    icon = src.icon,
    icons = src.icons,
    categories = { name },
    enabled = false, -- fixed_recipe runs regardless; keeps it out of the player's recipe lists
    hidden = false,
    hide_from_player_crafting = true,
    energy_required = def.recipe.energy_required,
    ingredients = def.recipe.ingredients,
    results = def.recipe.results,
    main_product = def.recipe.main_product,
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false,
    allow_decomposition = false,
    allow_as_intermediate = false,
    always_show_products = true,
    show_amount_in_title = false,
  }

  local entity = {
    type = "assembling-machine",
    name = name,
    icon = src.icon,
    icons = src.icons,
    flags = {
      "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable",
      "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable",
      "not-in-kill-statistics", "not-in-made-in",
      "player-creation", -- 2.1: loaders only connect to entities with this flag (2.10.1)
    },
    minable = nil,
    max_health = 10000,
    collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } },
    selection_box = { { -half, -half }, { half, half } },
    map_color = def.map_color or { r = 0.85, g = 0.65, b = 0.2 },
    graphics_set = graphics_set,
    working_sound = src.working_sound,
    fixed_recipe = name,
    show_recipe_icon = true,
    show_recipe_icon_on_map = true,
    crafting_categories = { name },
    crafting_speed = def.crafting_speed or 1,
    -- Electric cities: the engine draws energy_usage while crafting, slows down on low power
    -- and stops with none; idle drain is the engine default (1/30 of energy_usage).
    energy_source = def.burner and {
      type = "burner", fuel_categories = def.burner.fuel_categories, effectivity = 1,
      fuel_inventory_size = 1, burnt_inventory_size = 0,
    } or def.power and { type = "electric", usage_priority = "secondary-input" } or { type = "void" },
    energy_usage = def.burner and def.burner.power or def.power or "1W",
    module_slots = 0,
    allowed_effects = {},
    fluid_boxes = make_fluid_boxes(def.fluid_boxes, src.fluid_boxes and src or data.raw["assembling-machine"]["assembling-machine-2"]),
    fluid_boxes_off_when_no_fluid_recipe = false,
    impact_category = "metal",
  }
  for k, v in pairs(def.extra or {}) do entity[k] = v end

  return { category, recipe, entity }
end

--- Build a lab-type city (the research complex, PLAN 2.2.3). The engine runs research: the
--- packs go in by inserter, research speed is the tier cap, power is drawn like labs.
---   def: name, size, graphics (a lab), inputs (science pack names), researching_speed,
---        power, map_color
---@param def table
---@return table[]
function M.make_lab(def)
  local name = M.PREFIX .. def.name
  local size = def.size or 9
  local half = size / 2
  local src = source_prototype(def.graphics)
  local src_size = math.max(1, math.floor(src.collision_box[2][1] - src.collision_box[1][1] + 0.6))
  local factor = size / src_size
  local on_animation, off_animation = table.deepcopy(src.on_animation), table.deepcopy(src.off_animation)
  scale_sprites(on_animation, factor)
  scale_sprites(off_animation, factor)
  return { {
    type = "lab",
    name = name,
    icon = src.icon,
    icons = src.icons,
    flags = {
      "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable",
      "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable",
      "not-in-kill-statistics", "not-in-made-in",
      "player-creation", -- 2.1: loaders only connect to entities with this flag (2.10.1)
    },
    minable = nil,
    max_health = 10000,
    collision_box = { { -half + 0.1, -half + 0.1 }, { half - 0.1, half - 0.1 } },
    selection_box = { { -half, -half }, { half, half } },
    map_color = def.map_color or { r = 0.85, g = 0.65, b = 0.2 },
    on_animation = on_animation,
    off_animation = off_animation,
    working_sound = src.working_sound,
    inputs = def.inputs,
    researching_speed = def.researching_speed,
    energy_source = { type = "electric", usage_priority = "secondary-input" },
    energy_usage = def.power,
    module_slots = 0,
    allowed_effects = {},
    impact_category = "metal",
  } }
end

--- Build the rocket silo city (PLAN 2.5.6): the vanilla rocket silo, protected, with the
--- vanilla rocket part recipe. Its rockets launch by script (scripts/silo.lua), never to a
--- space platform. Space Age changes the vanilla silo in data-updates (after this), so the
--- fields that matter are set here explicitly.
---   def: name, parts (rocket parts per rocket), recipe ({ energy_required, ingredients,
---        results }: the city's own rocket part recipe), map_color
---@param def table
---@return table[]
function M.make_silo(def)
  local name = M.PREFIX .. def.name
  local silo = table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])
  silo.name = name
  silo.flags = {
    "placeable-neutral", "not-rotatable", "not-blueprintable", "not-deconstructable",
    "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable",
    "not-in-kill-statistics", "not-in-made-in",
    "player-creation", -- 2.1: loaders only connect to entities with this flag (2.10.1)
  }
  silo.minable = nil
  silo.placeable_by = nil
  silo.next_upgrade = nil
  silo.max_health = 10000
  silo.map_color = def.map_color
  silo.module_slots = 0
  silo.allowed_effects = {}
  -- Own rocket part recipe (user, 2.5.6: base-game amounts, not Space Age's 1 + 1 + 1).
  silo.crafting_categories = { name }
  silo.fixed_recipe = name
  silo.rocket_parts_required = def.parts
  silo.launch_to_space_platforms = false
  silo.surface_conditions = nil
  silo.heating_energy = nil
  silo.logistic_trash_inventory_size = 0
  local category = { type = "recipe-category", name = name }
  local recipe = {
    type = "recipe",
    name = name,
    icon = data.raw.item["rocket-part"].icon,
    categories = { name },
    enabled = false,
    hide_from_player_crafting = true,
    energy_required = def.recipe.energy_required,
    ingredients = def.recipe.ingredients,
    results = def.recipe.results,
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false,
    allow_decomposition = false,
    allow_as_intermediate = false,
  }
  return { category, recipe, silo }
end

return M
