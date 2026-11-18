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
})
