-- Settings stage: mod setting prototypes only.
data:extend({
  {
    type = "int-setting",
    name = "tt-goal-iron",
    setting_type = "runtime-global",
    default_value = 20000,
    minimum_value = 1,
    order = "a",
  },
  {
    type = "int-setting",
    name = "tt-goal-copper",
    setting_type = "runtime-global",
    default_value = 20000,
    minimum_value = 1,
    order = "b",
  },
  {
    -- 2.8.2: scales the minimum distance between cities on a procedural map
    type = "double-setting",
    name = "tt-city-spacing",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 0.5,
    maximum_value = 3,
    order = "c",
  },
})
