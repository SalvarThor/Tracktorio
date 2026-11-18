-- Custom inputs. Cities are not operable (hands-off), so the normal "open GUI" click does
-- nothing; this input follows the same control and opens the city detail window instead.
data:extend({
  {
    type = "custom-input",
    name = "tt-open-city",
    key_sequence = "",
    linked_game_control = "open-gui",
    consuming = "none",
  },
})
