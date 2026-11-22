-- Data-final-fixes: free logistics recipes, banned recipes, hand-crafting restriction,
-- technology cleanup. See SPEC "Rules" and DECISIONS.md (A1, A6).
local config = require("shared.config")

data:extend({
  { type = "recipe-category", name = config.FREE_CATEGORY },
})

--- Name of the first item a recipe produces, or nil.
local function main_item(recipe)
  if recipe.main_product and recipe.main_product ~= "" then return recipe.main_product end
  for _, r in pairs(recipe.results or {}) do
    if r.type == "item" then return r.name end
  end
  return nil
end

local function has_category(recipe, category)
  for _, c in pairs(recipe.categories or {}) do
    if c == category then return true end
  end
  return false
end

local banned_recipes = {}
local function ban(name, recipe)
  recipe.hidden = true
  recipe.enabled = false
  banned_recipes[name] = true
end

-- Items from other mods that place an entity of a free type (config.FREE_TYPES).
---@type table<string, string> entity name -> type
local entity_type = {}
for type in pairs(defines.prototypes.entity) do
  for name in pairs(data.raw[type] or {}) do entity_type[name] = type end
end
---@type table<string, boolean>
local free_items = {}
for name in pairs(config.FREE_SET) do free_items[name] = true end
for type in pairs(defines.prototypes.item) do
  for name, item in pairs(data.raw[type] or {}) do
    local place = item.place_result
    if place and config.FREE_TYPE_SET[entity_type[place] or ""] and not config.BANNED_SET[name]
        and string.sub(name, 1, 3) ~= "tt-" then
      free_items[name] = true
    end
  end
end
-- each free item keeps one recipe: the one named after it, else the first found
---@type table<string, string>
local free_recipe = {}
for name, recipe in pairs(data.raw.recipe) do
  local item = main_item(recipe)
  if item and free_items[item] and not has_category(recipe, "recycling") then
    if name == item or not free_recipe[item] then free_recipe[item] = name end
  end
end

for name, recipe in pairs(data.raw.recipe) do
  local item = main_item(recipe)
  if item and not has_category(recipe, "recycling") then
    if free_items[item] then
      if free_recipe[item] == name then
        recipe.ingredients = {}
        recipe.energy_required = config.FREE_CRAFT_TIME
        recipe.categories = { config.FREE_CATEGORY }
        recipe.allow_productivity = false
        recipe.auto_recycle = false -- nothing to recycle back into
      else
        ban(name, recipe) -- alternative recipes (e.g. casting-pipe) would duplicate the free one
      end
    elseif config.BANNED_SET[item] then
      ban(name, recipe)
    end
  end
end

-- Locomotives burn only the locomotive fuel category (tt-coal-fuel), not vanilla coal.
for _, loco in pairs(data.raw.locomotive) do
  if loco.energy_source and loco.energy_source.type == "burner" then
    loco.energy_source.fuel_categories = { config.LOCOMOTIVE_FUEL_CATEGORY }
  end
end

-- Keep the crafting menu to the free recipes: everything else would show as an uncraftable
-- red entry (playtest 1.10). Machines (cities) still see their own recipes.
for _, recipe in pairs(data.raw.recipe) do
  if not has_category(recipe, config.FREE_CATEGORY) then
    recipe.hide_from_player_crafting = true
  end
end

-- The character can only hand-craft the free recipes.
for _, character in pairs(data.raw.character) do
  character.crafting_categories = { config.FREE_CATEGORY }
end

-- Technologies: stop unlocking banned recipes; hide techs left with nothing to give.
for name, tech in pairs(data.raw.technology) do
  local had, kept = 0, {}
  for _, effect in pairs(tech.effects or {}) do
    had = had + 1
    if not (effect.type == "unlock-recipe" and banned_recipes[effect.recipe]) then
      kept[#kept + 1] = effect
    end
  end
  tech.effects = kept
  local hide = had > 0 and #kept == 0
  for _, pattern in ipairs(config.HIDDEN_TECH_PATTERNS) do
    if string.find(name, pattern) then hide = true end
  end
  if hide then
    tech.hidden = true
    tech.enabled = false
  end
end

-- A tech hidden for having nothing left to give must not cut the tree (2.6.2: Advanced
-- material processing only gave the steel furnace, and Concrete, so Uranium mining, sat
-- behind it). Its dependents take its prerequisites instead, transitively. Pattern-hidden
-- techs (planets, platforms) are left as they are: what sits behind them stays locked.
local function pattern_hidden(name)
  for _, pattern in ipairs(config.HIDDEN_TECH_PATTERNS) do
    if string.find(name, pattern) then return true end
  end
  return false
end
local function spliced(name, seen)
  local tech = data.raw.technology[name]
  if not (tech and tech.hidden and not pattern_hidden(name)) then return { name } end
  if seen[name] then return {} end
  seen[name] = true
  local out = {}
  for _, pre in ipairs(tech.prerequisites or {}) do
    for _, p in ipairs(spliced(pre, seen)) do out[#out + 1] = p end
  end
  return out
end
for _, tech in pairs(data.raw.technology) do
  if tech.prerequisites and not tech.hidden then
    local list, have = {}, {}
    for _, pre in ipairs(tech.prerequisites) do
      for _, p in ipairs(spliced(pre, {})) do
        if not have[p] then have[p] = true; list[#list + 1] = p end
      end
    end
    tech.prerequisites = list
  end
end
