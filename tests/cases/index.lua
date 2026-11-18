-- Test files, in run order. Each returns a list of { name = string, fn = function(ctx) }.
-- Files under "selftest" only run with --SelfTest; they fail on purpose to prove the
-- runner reports failures.
return {
  normal = {
    "__train-tycoon-tests__/cases/smoke",
  },
  selftest = {
    "__train-tycoon-tests__/cases/selftest",
  },
}
