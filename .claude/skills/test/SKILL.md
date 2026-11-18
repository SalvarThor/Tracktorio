---
name: test
description: Run static checks and the in-game automated test suite, then report results. Use after any code change and before ticking an item in docs/PLAN.md.
---

# Run the tests

Paths and commands come from `docs/ENV.md` and the Commands section of CLAUDE.md. Both
steps use the separate dev instance in `.factorio\`, so the user's own Factorio can stay
open.

1. Static check: `./tools/check.ps1`
   - Any diagnostic (warning or error) fails the run. Fix it before continuing.
   - After a Factorio update, run `./tools/check.ps1 -Regenerate` to rebuild the API types.
2. In-game tests: `./tools/run-tests.ps1`
   - Exit 0 = pass, 1 = test failures, 2 = harness/game error (load error, mod crash,
     timeout, no results). For 2 the script prints the log from the first error.
   - If you changed `tests/runner.lua` or `tools/run-tests.ps1`, also run
     `./tools/run-tests.ps1 -SelfTest`. It must exit 0.
3. If the game fails to start or a test errors, read
   `.factorio\data\factorio-current.log` and include the relevant lines in the report.
4. Report:
   - Static check: pass or the errors.
   - Tests: number passed and failed, with the name and message of each failure.
   - Anything in the log that looks wrong even if tests passed.

Do not tick a PLAN.md item while anything here fails.
