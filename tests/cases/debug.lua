local assert_ = require("__train-tycoon-tests__/assert")
local h = require("__train-tycoon-tests__/helpers")

return {
  {
    name = "debug: /tt-dump command is registered",
    fn = function()
      assert_.truthy(commands.commands["tt-dump"], "tt-dump not in commands.commands")
    end,
  },
  {
    name = "debug: tt-debug.dump returns storage as JSON",
    fn = function()
      local json = remote.call("tt-debug", "dump")
      assert_.equals(type(json), "string")
      local t = helpers.json_to_table(json)
      assert_.truthy(t, "dump is not valid JSON")
      ---@cast t table
      assert_.equals(t.mod_version, script.active_mods["train-tycoon"])
      assert_.equals(t.storage.tt_schema, 2, "storage.tt_schema")
    end,
  },
  {
    name = "debug: /tt-port-fill is registered and its remote twin fills a port",
    fn = function()
      assert_.truthy(commands.commands["tt-port-fill"], "tt-port-fill not registered")
      h.clear_area({ { 4400, -12 }, { 4422, 12 } })
      local city = h.place_city("tt-city-depot", { 4410.5, 0.5 })
      local pos = city.position
      remote.call("tt-city", "port_fill", city, 0.5)
      assert_.equals(remote.call("tt-city", "upgrade_status", city).delivered["iron-plate"], 500)
      remote.call("tt-city", "port_fill", h.port_of(city), 1)
      remote.call("tt-city", "port_tick")
      assert_.equals(assert(h.city_at(pos)).name, "tt-city-depot-t2")
    end,
  },
}