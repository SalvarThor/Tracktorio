-- 2.8: procedural maps.
local assert_ = require("__tracktorio-tests__/assert")
local city_defs = require("__tracktorio__/shared/city_defs")

return {
  {
    -- 2.8.1
    name = "mapgen: chain depth comes from the recipes; the depot is shallow and the silo deepest",
    fn = function()
      local depth = city_defs.depth
      for _, def in ipairs(city_defs.list) do
        assert_.truthy(depth[def.name] and depth[def.name] >= 1, def.name .. " has no depth")
      end
      for name, want in pairs({
        ["depot"] = 1, ["power"] = 1, ["iron-smelting"] = 1, ["refinery"] = 1,
        ["circuits"] = 2, ["uranium"] = 2, ["plastic"] = 2,
        ["green-science"] = 3, ["nuclear-power"] = 3, ["rocket-fuel-depot"] = 3,
        ["blue-science"] = 4, ["processing-units"] = 4,
        ["rocket-silo"] = 5,
      }) do
        assert_.equals(depth[name], want, name .. " depth")
      end
      for name, d in pairs(depth) do
        assert_.truthy(d <= depth["rocket-silo"], name .. " is deeper than the silo: " .. d)
      end
    end,
  },
}
