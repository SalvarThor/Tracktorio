-- Data-final-fixes (PLAN 2.15.3): no tile item can be placed on a plot (concrete, landfill,
-- any other mod's floor), so a plot stays a plot. A tile item's placement condition is a
-- collision mask its target tile must not have: add the plot layer to every one.
local config = require("shared.config")

for _, kind in ipairs({ "item", "item-with-entity-data", "rail-planner", "tool", "capsule", "repair-tool" }) do
  for _, item in pairs(data.raw[kind] or {}) do
    local t = item.place_as_tile
    if t then
      t.condition = t.condition or { layers = {} }
      t.condition.layers = t.condition.layers or {}
      t.condition.layers[config.PLOT_LAYER] = true
      t.condition_size = t.condition_size or 1
    end
  end
end
