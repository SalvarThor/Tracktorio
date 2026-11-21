-- Plots (PLAN 2.15): 12x12 patches of plot tiles, the only ground a city can be built on
-- (prototypes/plot.lua). A border ring of hazard stripes around refined concrete.
local config = require("shared.config")
local port_layout = require("shared.port_layout")

local M = {}

M.SIZE = port_layout.SIZE

--- Tile area of the plot whose city would stand at `position` (a city position as
--- cities.place takes it: a tile centre; even sizes snap to the corner at its top left).
---@param position MapPosition|number[]
function M.area(position)
  local x = math.floor(position.x or position[1])
  local y = math.floor(position.y or position[2])
  local h = M.SIZE / 2
  return { left_top = { x = x - h, y = y - h }, right_bottom = { x = x + h, y = y + h } }
end

--- Paint a plot under the city position `position`.
---@param surface LuaSurface
---@param position MapPosition|number[]
function M.paint(surface, position)
  local a = M.area(position)
  local x0, y0, x1, y1 = a.left_top.x, a.left_top.y, a.right_bottom.x - 1, a.right_bottom.y - 1
  local tiles = {}
  for x = x0, x1 do
    for y = y0, y1 do
      local edge = x == x0 or x == x1 or y == y0 or y == y1
      tiles[#tiles + 1] = { name = edge and config.PLOT_BORDER_TILE or config.PLOT_TILE, position = { x, y } }
    end
  end
  surface.set_tiles(tiles, true, true, true, false)
end

--- Is the plot area under `position` free of anything the player built (so painting it
--- moves nothing of theirs)?
---@param surface LuaSurface
---@param position MapPosition|number[]
function M.free(surface, position)
  return surface.count_entities_filtered({ area = M.area(position), force = "player" }) == 0
end

return M
