local assert_ = require("__tracktorio-tests__/assert")
local h = require("__tracktorio-tests__/helpers")

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
      assert_.equals(t.mod_version, script.active_mods["tracktorio"])
      assert_.equals(t.storage.tt_schema, 3, "storage.tt_schema")
    end,
  },
}