-- Tracktorio scenario (2.8.10): the way to play. The mod sets up procedural Nauvis in its
-- own on_init (scripts/nauvis.lua) and gives the starting items; the scenario only greets.
-- (Until 2.8.10 it played the fixed hand-made map, which the tests still build through the
-- "tt-map" remote interface.)
script.on_event(defines.events.on_player_created, function(e)
  local player = game.get_player(e.player_index)
  if player then player.print({ "tt-scenario.welcome" }) end
end)