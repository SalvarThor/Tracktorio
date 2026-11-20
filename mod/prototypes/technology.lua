-- Vanilla technologies retuned for Tracktorio. Data stage, final fixes (after Space Age).

-- 2.7.1: Elevated rail. Space Age: 100 x red/green/blue/purple after Concrete and Production
-- science pack. The research complex takes no purple (DECISIONS 2026-11-20), so: red, green
-- and blue, 500 units x 30 s, after Concrete and Chemical science pack. Unlocks unchanged
-- (rail ramp, rail support, building elevated rails); those items are free (restrictions).
local elevated = data.raw.technology["elevated-rail"]
if elevated then
  elevated.prerequisites = { "concrete", "chemical-science-pack" }
  elevated.unit = {
    count = 500,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  }
end
