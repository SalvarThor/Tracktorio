local assert_ = require("__tracktorio-tests__/assert")

return {
  {
    name = "smoke: arithmetic",
    fn = function()
      assert_.equals(1 + 1, 2)
    end,
  },
  {
    name = "smoke: game is running with tracktorio loaded",
    fn = function()
      assert_.truthy(game.surfaces[1], "no surface")
      assert_.truthy(script.active_mods["tracktorio"], "tracktorio not active")
      assert_.truthy(script.active_mods["space-age"], "space-age not active")
    end,
  },
  {
    name = "smoke: quality mod is not active",
    fn = function()
      assert_.falsy(script.active_mods["quality"], "quality is active")
    end,
  },
  {
    name = "smoke: waiting across ticks works",
    fn = function(ctx)
      local start = game.tick
      ctx:wait(10, function()
        assert_.equals(game.tick - start, 10)
      end)
    end,
  },
}
