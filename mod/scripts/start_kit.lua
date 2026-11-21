-- Personal construction robots (user, 2026-11-21): building is free, so building fast is
-- fine. Every new player starts wearing power armor with a portable fission reactor, two
-- personal roboports and two batteries, and carries construction robots. Personal only:
-- no roboports on the ground and no logistic robots, so robots never move cargo between
-- places. Construction robots are a free hand-craft (config.FREE_ITEMS), to replace losses.
local config = require("shared.config")

local M = {}

--- Put the kit on a player (once per player; storage.tt_start_kit[player_index]).
---@param player LuaPlayer
function M.give(player)
  storage.tt_start_kit = storage.tt_start_kit or {}
  if storage.tt_start_kit[player.index] then return end
  local character = player.character
  if not (character and character.valid) then return end
  storage.tt_start_kit[player.index] = true
  local kit = config.START_KIT
  local armor_inv = character.get_inventory(defines.inventory.character_armor)
  if armor_inv and armor_inv.is_empty() and armor_inv.insert({ name = kit.armor, count = 1 }) == 1 then
    local grid = armor_inv[1].grid
    if grid then
      for _, e in ipairs(kit.equipment) do
        for _ = 1, e.count do grid.put({ name = e.name }) end
      end
    end
  else
    player.insert({ name = kit.armor, count = 1 }) -- armor slot taken: into the inventory, unfitted
  end
  player.insert({ name = "construction-robot", count = kit.robots })
end

return M
