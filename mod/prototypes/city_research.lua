-- Data-final-fixes, before restrictions.lua (PLAN 2.15.5): each technology in
-- city_defs.UNLOCK unlocks building its city kinds ("tt-build-<entity>"). A technology that
-- had nothing else left to give now gives a city, so restrictions.lua keeps it visible.
local config = require("shared.config")
local defs = require("shared.city_defs")

-- Rocket silo: with platforms and planets off it gives the rocket silo city alone (not the
-- vanilla silo, rocket part, cargo landing pad or platform starter pack).
local silo = data.raw.technology["rocket-silo"]
if silo then silo.effects = {} end

for _, def in ipairs(defs.list) do
  if def.unlock then
    local tech = assert(data.raw.technology[def.unlock], "tt: no technology " .. def.unlock .. " for " .. def.name)
    tech.effects = tech.effects or {}
    table.insert(tech.effects, { type = "unlock-recipe", recipe = config.CITY_BUILD_RECIPE_PREFIX .. defs.entity_name(def.name) })
  end
end
