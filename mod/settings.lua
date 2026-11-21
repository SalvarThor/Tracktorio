-- Settings stage: mod setting prototypes only.
-- (The goal box targets were map settings until playtest 2.8.7; they live in storage now.)
data:extend({
  {
    -- 2.8.2: scales the minimum distance between plot sites (cities until 2.15) on a procedural map
    type = "double-setting",
    name = "tt-city-spacing",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 0.5,
    maximum_value = 3,
    order = "c",
  },
})