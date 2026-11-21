-- Personal construction robots (user, 2026-11-21): every player starts with power armor
-- holding a fission reactor, two personal roboports and two batteries, and 20 construction
-- robots. Roboports on the ground and logistic robots stay out.
local assert_ = require("__tracktorio-tests__/assert")

return {
  {
    name = "start kit: power armor with reactor, two roboports and batteries, and 20 construction robots",
    fn = function()
      local p = assert(game.players[1])
      local character = assert(p.character, "the test player has no character")
      local armor = assert(character.get_inventory(defines.inventory.character_armor))
      armor.clear()
      local before = p.get_item_count("construction-robot")
      remote.call("tt-city", "give_start_kit", p.index)
      assert_.equals(armor[1].valid_for_read and armor[1].name, "power-armor", "armor")
      local grid = assert(armor[1].grid, "no equipment grid")
      local have = {}
      for _, e in ipairs(grid.equipment) do have[e.name] = (have[e.name] or 0) + 1 end
      assert_.equals(have["fission-reactor-equipment"], 1, "reactor")
      assert_.equals(have["personal-roboport-equipment"], 2, "roboports")
      assert_.equals(have["battery-equipment"], 2, "batteries")
      assert_.equals(p.get_item_count("construction-robot") - before, 20, "robots")
      armor.clear()
      p.remove_item({ name = "construction-robot", count = 20 })
    end,
  },
  {
    name = "start kit: construction robots are a free hand-craft; roboports and logistic robots stay out",
    fn = function()
      local force = game.forces["player"]
      local bot = force.recipes["construction-robot"]
      assert_.truthy(bot.enabled, "construction robot recipe not unlocked")
      assert_.equals(#bot.prototype.ingredients, 0, "construction robot ingredients")
      for _, name in ipairs({ "roboport", "logistic-robot" }) do
        local r = force.recipes[name]
        assert_.truthy(r == nil or (not r.enabled and r.prototype.hidden), name .. " can be crafted")
      end
    end,
  },
}
