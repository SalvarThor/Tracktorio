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

for name, recipe in pairs(data.raw.recipe) do
  local item = main_item(recipe)
  if item and not has_category(recipe, "recycling") then
    if config.FREE_SET[item] then
      if name == item then
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
