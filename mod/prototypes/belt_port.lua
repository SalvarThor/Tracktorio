-- Belt port (PLAN 2.10.4): a hidden loader under a city's wall, one per item the city
-- takes or gives. The player's belt ends on the tile just outside the wall and runs into
-- it (or out of it). Placed, filtered and protected by scripts/belt_ports.lua.
-- It sits inside the building and draws no structure: the
-- building covers it, and markers drawn by script show where it is. It collides with belts
-- only (2.1 requires that much of a loader).
local config = require("shared.config")

local empty = { filename = "__core__/graphics/empty.png", width = 1, height = 1, priority = "extra-high" }

local port = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
port.name = config.BELT_PORT
port.hidden = true
port.hidden_in_factoriopedia = true
port.flags = {
  "placeable-neutral", "player-creation", "not-rotatable", "not-blueprintable", "not-deconstructable",
  "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable", "not-in-kill-statistics",
  "not-on-map",
}
port.minable = nil
port.max_health = 10000
port.collision_mask = { layers = { transport_belt = true } } -- 2.1: a loader must collide with belts; nothing else, so it sits inside the city
port.selection_priority = 60 -- above the city: hovering the port shows what it is
port.speed = 0.125 -- as fast as the fastest belt (turbo, 60/s): the player's belt is the limit
port.filter_count = 1
port.structure = { direction_in = { sheet = empty }, direction_out = { sheet = empty } }
-- No belt either (playtest 2.10: a sliver of moving belt showed at an unconnected port): a
-- transparent sheet with the 20 belt directions, one frame each.
port.belt_animation_set = {
  animation_set = { filename = "__tracktorio__/graphics/empty-belt.png", priority = "extra-high",
    width = 1, height = 1, frame_count = 1, direction_count = 20 },
}
port.next_upgrade = nil
port.fast_replaceable_group = nil

-- A depot's service port (2.10.6) feeds a hidden chest two tiles in, clear of the tile in
-- front of every item port. Its own prototype, so it explains itself when hovered (2.10.14).
local service_port = table.deepcopy(port)
service_port.name = config.SERVICE_BOX_PORT
service_port.container_distance = 2
service_port.icon = "__base__/graphics/icons/repair-pack.png"

data:extend({ port, service_port })
