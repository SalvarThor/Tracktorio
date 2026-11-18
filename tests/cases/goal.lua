-- 1.5: goal box, cumulative delivery count, win condition, progress panel.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local GOAL = "tt-city-goal"

local function status() return remote.call("tt-goal", "status") end

return {
  {
    name = "goal: inserters deliver plates and they are counted cumulatively",
    fn = function(ctx)
      local before = status().delivered
      local box = h.city_rig(GOAL, 800, { { name = "iron-plate", count = 30 } }, false)
      ctx:wait_until(function()
        remote.call("tt-goal", "tick")
        return status().delivered.iron >= before.iron + 30
      end, 60 * 60, function()
        local inv = assert(box.get_inventory(defines.inventory.chest))
        assert_.equals(inv.get_item_count("iron-plate"), 0, "box not emptied")
        assert_.equals(status().delivered.copper, before.copper, "copper changed")
      end)
    end,
  },
  {
    name = "goal: the box only accepts iron and copper plates",
    fn = function(ctx)
      local box = h.city_rig(GOAL, 840, { { name = "coal", count = 20 }, { name = "iron-gear-wheel", count = 20 } }, false)
      local inv = assert(box.get_inventory(defines.inventory.chest))
      assert_.falsy(inv.can_insert({ name = "coal", count = 1 }), "coal insertable")
      assert_.truthy(inv.can_insert({ name = "copper-plate", count = 1 }), "copper not insertable")
      ctx:wait(60 * 5, function()
        assert_.equals(inv.get_item_count(), 0, "something non-plate got in")
      end)
    end,
  },
  {
    name = "goal: delivery rate per minute is reported",
    fn = function(ctx)
      local box = h.city_rig(GOAL, 880, { { name = "copper-plate", count = 100 } }, false)
      ctx:wait(60 * 10, function()
        remote.call("tt-goal", "tick")
        assert_.truthy(status().rates.copper > 0, "copper rate " .. status().rates.copper)
        assert_.truthy(box.valid)
      end)
    end,
  },
  {
    name = "goal: progress panel is shown to the player",
    fn = function(ctx)
      ctx:wait(61, function()
        local p = assert(game.players[1])
        local frame = p.gui.left["tt_goal_frame"]
        assert_.truthy(frame, "no goal frame")
        ---@cast frame LuaGuiElement
        assert_.truthy(frame["iron"] and frame["copper"], "missing rows")
      end)
    end,
  },
  {
    name = "goal: stops accepting a metal once its target is met",
    fn = function(ctx)
      local s = status()
      local iron_target = s.delivered.iron + 10
      remote.call("tt-goal", "set_targets", iron_target, s.delivered.copper + 100000)
      local box, cin = h.city_rig(GOAL, 960, { { name = "iron-plate", count = 40 } }, false)
      ctx:wait_until(function() return status().delivered.iron >= iron_target end, 60 * 60, function()
        ctx:wait(60 * 10, function()
          remote.call("tt-goal", "tick")
          local inv = assert(box.get_inventory(defines.inventory.chest))
          assert_.falsy(inv.can_insert({ name = "iron-plate", count = 1 }), "still accepts iron")
          assert_.truthy(inv.can_insert({ name = "copper-plate", count = 1 }), "copper closed too")
          assert_.truthy(status().delivered.iron <= iron_target + 5, "overshoot " .. (status().delivered.iron - iron_target))
          assert_.truthy(cin.get_item_count("iron-plate") >= 20, "kept taking iron: " .. cin.get_item_count("iron-plate") .. " left")
          remote.call("tt-goal", "set_targets", 20000, 20000)
          assert_.truthy(inv.can_insert({ name = "iron-plate", count = 1 }), "raising the target did not reopen iron")
        end)
      end)
    end,
  },
  {
    name = "goal: reaching both targets wins, one alone does not",
    fn = function(ctx)
      local s = status()
      remote.call("tt-goal", "set_targets", s.delivered.iron + 10, s.delivered.copper + 10)
      local box = h.city_rig(GOAL, 920, {}, false)
      local inv = assert(box.get_inventory(defines.inventory.chest))
      inv.insert({ name = "iron-plate", count = 10 })
      remote.call("tt-goal", "tick")
      assert_.falsy(status().won, "won on iron alone")
      inv.insert({ name = "copper-plate", count = 10 })
      remote.call("tt-goal", "tick")
      assert_.truthy(status().won, "not won with both targets met")
      ctx:wait(2, function()
        assert_.truthy(game.finished or game.finished_but_continuing, "game not marked finished")
      end)
    end,
  },
}
