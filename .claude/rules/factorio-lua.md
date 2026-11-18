---
paths:
  - "mod/**/*.lua"
  - "tests/**/*.lua"
---

# Factorio Lua rules

Verify API names against https://lua-api.factorio.com/latest/ when unsure. These rules
reflect 2.0 knowledge; if 2.1 differs, follow the docs and note it in DECISIONS.md.

## Known 2.1 changes (verified on 2.1.24; details in DECISIONS.md)
- Items: `fuel_categories = {...}`, not `fuel_category` (load error).
- Recipes: `categories = {...}`, not `category`/`additional_categories` (load error).
  `energy_required` must be `> 0.001`.
- Linked fluidbox connections: `LuaEntity.add_fluid_box_linked_connection`.
- `RecipePrototype.raise_on_crafted` + `RecipeCraftedEvent` (crafting machines only).
- Burner: writing `currently_burning` needs `remaining_burning_fuel` set too.

## Stages
- Settings stage (`settings.lua`, ...): mod settings prototypes only.
- Data stage (`data.lua`, `data-updates.lua`, `data-final-fixes.lua`): prototypes only, via
  `data:extend`. No runtime API. Changes to vanilla prototypes go in `data-updates.lua` or
  `data-final-fixes.lua` so other mods' changes are visible.
- Control stage (`control.lua` and modules it requires): runtime only. No access to `data`.

## State and determinism (multiplayer-safe by default)
- All persistent state lives in `storage` (2.0 renamed `global` to `storage`).
- `script.on_load` must never write to `storage` or the game state. It may only restore
  metatables and local references.
- Initialize state in `script.on_init`; migrate it in `script.on_configuration_changed`.
- No module-level variables that hold game state between ticks unless they are rebuilt
  identically from `storage` in `on_load`.
- Never branch game logic on a specific player's view, GUI state or local client data.
- Use `helpers.write_file` (not `game.write_file`) for script-output files.

## Robustness
- Check `.valid` on any stored LuaEntity, LuaTrain or GUI element before use.
- Handle every way an entity can disappear: mined, destroyed, script-destroyed, surface
  cleared.
- Prefer `script.on_nth_tick` and spreading work across ticks over doing everything in
  `on_tick`.
- Register event filters where the API supports them.

## Conventions
- Prefix prototype names, remote interfaces and commands with `tt-`. Storage keys use `tt_`
  (`storage.tt_schema`), because Lua identifiers can't contain `-`.
- Every `/tt-*` debug command has a function on the `tt-debug` remote interface, so tests can
  call it.

## Tests
- Test cases live in `tests/cases/*.lua`, listed in `tests/cases/index.lua`. Each returns
  `{ { name = ..., fn = function(ctx) ... end }, ... }`.
- They run in the test scenario's Lua state, not the mod's. Reach the mod through game state,
  `remote.call("tt-debug", ...)` and other remote interfaces.
- Multi-tick tests: `ctx:wait(ticks, fn)` or `ctx:wait_until(pred, max_ticks, fn)`, one at a
  time. Chain them by calling again inside `fn`.
- `require` works only at load time (top level), never inside a test body.
- One module per concern under `mod/scripts/`, required from `control.lua`.
- Every prototype name has a locale entry.
- Prototype renames need a migration file in `mod/migrations/`.
