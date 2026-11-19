-- Test files, in run order. Each returns a list of { name = string, fn = function(ctx) }.
-- Files under "selftest" only run with --SelfTest; they fail on purpose to prove the
-- runner reports failures.
return {
  normal = {
    "__train-tycoon-tests__/cases/smoke",
    "__train-tycoon-tests__/cases/debug",
    "__train-tycoon-tests__/cases/restrictions",
    "__train-tycoon-tests__/cases/cities",
    "__train-tycoon-tests__/cases/mvp_cities",
    "__train-tycoon-tests__/cases/intermediates",
    "__train-tycoon-tests__/cases/research",
    "__train-tycoon-tests__/cases/gating",
    "__train-tycoon-tests__/cases/power",
    "__train-tycoon-tests__/cases/tiers",
    "__train-tycoon-tests__/cases/ports",
    "__train-tycoon-tests__/cases/upgrade",
    "__train-tycoon-tests__/cases/upgrade_ui",
    "__train-tycoon-tests__/cases/migration",
    "__train-tycoon-tests__/cases/tier_marks",
    "__train-tycoon-tests__/cases/framework",
    "__train-tycoon-tests__/cases/city_ui",
    "__train-tycoon-tests__/cases/ui_22",
    "__train-tycoon-tests__/cases/limp",
    "__train-tycoon-tests__/cases/reliability",
    "__train-tycoon-tests__/cases/service",
    "__train-tycoon-tests__/cases/fuels",
    "__train-tycoon-tests__/cases/oil",
    "__train-tycoon-tests__/cases/map",
    "__train-tycoon-tests__/cases/e2e",
    -- keep last: winning finishes the game
    "__train-tycoon-tests__/cases/goal",
  },
  selftest = {
    "__train-tycoon-tests__/cases/selftest",
  },
}
