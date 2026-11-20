-- 2.7: elevated rails (Space Age), unlocked by red/green/blue research.
local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

local X = 12000

--- Run fn with Elevated rail researched, then put it back.
local function with_research(fn)
  local tech = game.forces["player"].technologies["elevated-rail"]
  local was = tech.researched
  tech.researched = true
  local ok, err = pcall(fn)
  tech.researched = was
  if not ok then error(err, 0) end
end

return {
  {
    name = "elevated: ramps and supports are locked before Elevated rail, then free and hand-craftable",
    fn = function()
      local force = game.forces["player"]
      assert_.falsy(force.technologies["elevated-rail"].researched, "researched at the start")
      for _, name in ipairs({ "rail-ramp", "rail-support" }) do
        assert_.falsy(force.recipes[name].enabled, name .. " unlocked at the start")
      end
      assert_.falsy(force.rail_planner_allow_elevated_rails, "elevated building allowed at the start")
      with_research(function()
        assert_.truthy(force.rail_planner_allow_elevated_rails, "elevated building not allowed")
        local p = assert(game.players[1])
        p.get_main_inventory().clear()
        for _, name in ipairs({ "rail-ramp", "rail-support" }) do
          local r = force.recipes[name]
          assert_.truthy(r.enabled, name .. " not unlocked")
          assert_.equals(#r.ingredients, 0, name .. " ingredients")
          assert_.equals(r.prototype.categories[1], "tt-free", name .. " category")
          assert_.truthy(p.get_craftable_count(name) > 0, name .. " not hand-craftable")
        end
      end)
    end,
  },
  {
    name = "elevated: the elevated rails and signals use the free rail and signal items",
    fn = function()
      for entity, item in pairs({
        ["elevated-straight-rail"] = "rail",
        ["elevated-curved-rail-a"] = "rail",
        ["elevated-half-diagonal-rail"] = "rail",
        ["rail-signal"] = "rail-signal",
        ["rail-chain-signal"] = "rail-signal",
      }) do
        local p = assert(prototypes.entity[entity], entity)
        local items = p.items_to_place_this or {}
        local found = false
        for _, i in ipairs(items) do if i.name == item or (item == "rail-signal" and i.name == entity) then found = true end end
        assert_.truthy(found, entity .. " placed by " .. serpent.line(items))
      end
      for _, item in ipairs({ "rail", "rail-signal", "rail-chain-signal" }) do
        local r = prototypes.recipe[item]
        assert_.equals(#r.ingredients, 0, item .. " ingredients")
      end
    end,
  },
  {
    -- 2.7.2: supports stand on water (not deep oil ocean, which isn't on this map), so
    -- elevated track can cross the lakes.
    name = "elevated: rail supports can stand in water and deep water (ground rail cannot)",
    fn = function()
      local s = h.surface()
      h.clear_area({ { X - 10, -10 }, { X + 10, 10 } })
      local tiles = {}
      for x = X - 8, X + 7 do
        for y = -8, 7 do tiles[#tiles + 1] = { name = x < X and "water" or "deepwater", position = { x, y } } end
      end
      s.set_tiles(tiles)
      for _, spot in ipairs({ { X - 4, 0, "water" }, { X + 4, 0, "deepwater" } }) do
        assert_.equals(s.get_tile(spot[1], spot[2]).name, spot[3])
        assert_.truthy(s.can_place_entity({ name = "rail-support", position = { spot[1], spot[2] }, force = "player" }),
          "rail support refused on " .. spot[3])
      end
      assert_.falsy(s.can_place_entity({ name = "straight-rail", position = { X + 4, 0 }, force = "player" }),
        "ground rail allowed on deep water")
      local fill = {}
      for x = X - 8, X + 7 do for y = -8, 7 do fill[#fill + 1] = { name = "grass-1", position = { x, y } } end end
      s.set_tiles(fill)
    end,
  },
}
