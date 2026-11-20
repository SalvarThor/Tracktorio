-- 2.1.7: tier pips drawn on each tiered city.
local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

local function marks(city) return remote.call("tt-city", "tier_marks", city) end

return {
  {
    name = "tier marks: a tier 1 city shows 1 of 3 pips; the goal box shows none",
    fn = function()
      h.clear_area({ { 4200, -12 }, { 4250, 12 } })
      local city = h.place_city("tt-city-iron-smelting", { 4210.5, 0.5 })
      local m = assert(marks(city), "no pips")
      assert_.equals(m.total, 3)
      assert_.equals(m.filled, 1)
      local goal = h.place_city("tt-city-goal", { 4235.5, 0.5 })
      assert_.equals(marks(goal), nil)
    end,
  },
  {
    name = "tier marks: upgrading fills the next pip (tier 2, then tier 3)",
    fn = function()
      h.clear_area({ { 4200, -12 }, { 4250, 12 } })
      local city = h.place_city("tt-city-depot", { 4210.5, 0.5 })
      local t2 = assert(remote.call("tt-city", "upgrade_now", city))
      assert_.equals(assert(marks(t2)).filled, 2)
      local t3 = assert(remote.call("tt-city", "upgrade_now", t2))
      local m = assert(marks(t3))
      assert_.equals(m.filled, 3)
      assert_.equals(m.total, 3)
    end,
  },
  {
    name = "tier marks: migration redraws lost pips and does not duplicate them",
    fn = function()
      h.clear_area({ { 4200, -12 }, { 4250, 12 } })
      local city = h.place_city("tt-city-copper-smelting", { 4210.5, 0.5 })
      local before = #rendering.get_all_objects("train-tycoon")
      remote.call("tt-city", "migrate")
      assert_.equals(#rendering.get_all_objects("train-tycoon"), before, "migration duplicated pips")
      rendering.clear("train-tycoon")
      assert_.equals(marks(city), nil)
      remote.call("tt-city", "migrate")
      assert_.equals(assert(marks(city), "pips not redrawn").filled, 1)
    end,
  },
  {
    name = "tier marks: the single-tier rocket silo has no pips, and migration removes old ones",
    fn = function()
      h.clear_area({ { 4200, -12 }, { 4250, 12 } })
      local silo = h.place_city("tt-city-rocket-silo", { 4215.5, 0.5 })
      assert_.equals(marks(silo), nil, "silo has pips")
      -- an older save drew one pip on the silo
      remote.call("tt-city", "add_legacy_pip", silo)
      assert_.equals(assert(marks(silo), "legacy pip not drawn").total, 1)
      local before = #rendering.get_all_objects("train-tycoon")
      remote.call("tt-city", "migrate")
      assert_.equals(#rendering.get_all_objects("train-tycoon"), before - 1, "legacy pip not destroyed")
      assert_.equals(marks(silo), nil, "migration drew silo pips")
    end,
  },
}
