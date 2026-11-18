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
    "__train-tycoon-tests__/cases/power",
    -- keep last: winning finishes the game
    "__train-tycoon-tests__/cases/goal",
  },
  selftest = {
    "__train-tycoon-tests__/cases/selftest",
  },
}
