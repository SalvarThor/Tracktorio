-- Test scenario. Run with:
--   factorio.exe --test-scenario train-tycoon-tests/tt-tests --test-arg "<args>"
-- tools/run-tests.ps1 does this. The runner lives in the scenario script (its own Lua
-- state), so its event handlers never replace the mod's.
require("__train-tycoon-tests__/runner")
