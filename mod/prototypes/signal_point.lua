-- City signal points (PLAN 2.11): two constant combinators in the door of every city, in the
-- middle of its south wall. The player wires to them; scripts/signals.lua writes what they
-- send. The stock point sends what the city holds, its status and tier; the construction
-- point sends the materials its next tier still needs. They keep the vanilla combinator
-- look, so it is plain where to wire, and they sit inside the building: they collide with
-- nothing.
local config = require("shared.config")

local function point(name, icons)
  local p = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  p.name = name
  p.icon, p.icons = nil, icons
  p.hidden = true
  p.hidden_in_factoriopedia = true
  p.flags = {
    "placeable-neutral", "player-creation", "not-rotatable", "not-blueprintable", "not-deconstructable",
    "not-upgradable", "no-copy-paste", "not-flammable", "not-repairable", "not-in-kill-statistics",
  }
  p.minable = nil
  p.max_health = 10000
  p.corpse, p.dying_explosion = nil, nil
  p.collision_mask = { layers = {} }
  p.selection_priority = 60 -- above the city
  p.fast_replaceable_group = nil
  p.next_upgrade = nil
  return p
end

local combinator = { icon = "__base__/graphics/icons/constant-combinator.png" }
data:extend({
  point(config.SIGNAL_POINT, { combinator }),
  point(config.CONSTRUCTION_SIGNAL_POINT, { combinator,
    { icon = "__base__/graphics/icons/steel-chest.png", scale = 0.3, shift = { 8, 8 }, floating = true } }),
})

-- Status signals: value 1 while the city is in that state.
local function status(name, icon, order)
  return { type = "virtual-signal", name = name, icon = "__base__/graphics/icons/signal/" .. icon,
    subgroup = "virtual-signal", order = "z[tracktorio]-" .. order }
end
data:extend({
  status(config.SIGNAL.running, "signal-checked-green.png", "a"),
  status(config.SIGNAL.starved, "signal-hourglass.png", "b"),
  status(config.SIGNAL.output_full, "signal-no-entry.png", "c"),
  status(config.SIGNAL.no_power, "signal-lightning.png", "d"),
  status(config.SIGNAL.speed, "signal-clock.png", "e"),
})
