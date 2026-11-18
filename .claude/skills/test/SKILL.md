---
name: test
description: Run static checks and the in-game automated test suite, then report results. Use after any code change and before ticking an item in docs/PLAN.md.
---

# Run the tests

Paths and commands come from `docs/ENV.md` and the Commands section of CLAUDE.md. Phase 0
replaces the placeholders below.

1. Static check: `<TBD in Phase 0, e.g. ./tools/check.ps1>`
   - Any error fails the run. Fix it before continuing.
2. In-game tests: `<TBD in Phase 0, e.g. ./tools/run-tests.ps1>`
   - Make sure no other Factorio instance is running first.
3. If the game fails to start or a test errors, read the end of `factorio-current.log`
   (path in docs/ENV.md) and include the relevant lines in the report.
4. Report:
   - Static check: pass or the errors.
   - Tests: number passed and failed, with the name and message of each failure.
   - Anything in the log that looks wrong even if tests passed.

Do not tick a PLAN.md item while anything here fails.
