# Project Slimming Overall Progress

## Baseline

- Date: 2026-07-02
- Base commit: `51ec0972b219626780e1f31909885adad7dd120d`
- Main branch: `master`
- Validation engine used for final Batch 2 gates: Godot `4.7.stable.official.5b4e0cb0f`
- Project feature declaration: Godot 4.7
- Existing untracked prompt files were preserved and not overwritten.

## Completed first-round batches

### UI-1: task module dialog controller

- Extracted task-module confirmation and replacement state into `TaskModuleDialogController`.
- `UI.gd` retains the two public compatibility facades.
- Removed six task-module pending/custom-button fields and the old internal implementation.
- `UI.gd`: 1802 -> 1683 lines; 208 -> 199 functions.
- New controller has no `owner_ui`/Owner back-reference.

### Player-1: pure movement calculation pilot

- `PlayerMovementSystem` no longer holds or reads a Player owner.
- Added reusable typed `MovementFrameInput` and `MovementFrameResult`.
- Player still owns input/phase collection, movement flags, CharacterBody2D velocity/position application, and navigation lifecycle.
- Movement-system `_player` references: 46 -> 0.
- 100,000 repeated ticks: ObjectDB delta 0; integrated milestone run 332,167 usec.
- `Player.gd`: 1786 -> 1828 lines because the engine-adapter boundary is now explicit; the 700-line soft target remains a later-phase goal.

### Test infrastructure batch 1

- Added versioned pilot manifest schema, source-domain map, conservative selector, CLI, self-tests, and registration documentation.
- Selector covers empty, single-domain, multi-domain, core, manifest, uncertain, unknown, docs-only, and explicit-append cases.
- Core, Autoload, manifest/selector, uncertain data/asset paths, and unknown production paths fail closed to all registered tests.
- Catalog contains 11 representative entries after coordinator registration; it is still `pilot` and does not replace the historical full suite.
- Limited-parallel isolated Worker remains the next independent infrastructure batch.

### Startup-1: repeatable baseline and manifest design

- Added an isolated cold-import/hot-start/directed-test benchmark with JSON output.
- Added a menu-to-world baseline probe and a design-only static resource manifest audit.
- Static manifest: 8 catalogs, 93 resources; `runtime_consumed=false`.
- Cold import: 61,379 ms; 425 imported files; 0 runtime errors.
- Hot start (5 runs): median 8,267 ms.
- Directed startup test (5 runs): median 12,304 ms; all PASS.
- No production startup path or Autoload behavior changed.

### Asset pipeline batch 1

- Completed a read-only audit of 425 tracked asset paths; `asset/**` has no changes.
- 214 source files plus 211 `.import` sidecars; total 78.33 MiB.
- 34 source files have no direct text reference, but this is not deletion proof.
- Found one orphan PNG `.import`, two tiny exact SVG duplicate groups, and no decoded PNG pixel duplicates.
- The active TTF is Thin while the unreferenced OTF is Regular; direct replacement is prohibited without visual gates.
- `characters_move.zip` duplicates all 42 extracted runtime frames but has no importer, so it is a repository-archive candidate rather than proven cold-import savings.

## Stage two checkpoint

- Integrated the limited-parallel Godot Worker from the test infrastructure batch, then reran the representative coordinator manifest after each business-range integration point.
- Fixed the Worker classification boundary: known Godot shutdown leak diagnostics after an explicit `PASS` are retained as shutdown diagnostics instead of runtime `ERROR`; real runtime errors still classify as `ERROR`.
- Worker process isolation now assigns unique `GODOT_USER_HOME`, `APPDATA`, and `LOCALAPPDATA` roots per test process; only `parallel_safe=true` and `writes_user_data=false` entries can overlap.
- Worker self-tests cover parser PASS/FAIL/ERROR, missing completion markers, timeout process-tree termination, scheduling, retained logs, reproduction commands, and Windows `user://` isolation.
- Player-2A and Player-2B are integrated: `player.active_skill_characterization` protects active-skill behavior, and `PlayerActiveSkillRuntime` now delegates energy, player-skill setup/cast, and weapon active/reload/hint responsibilities to `SkillEnergyState`, `PlayerSkillController`, and `WeaponActionController`.
- Startup-2 is integrated for all eight startup manifest catalogs: routes, cell effects, task modules, weapons, mechas, economy, weapon branches, and weapon passives now consume `data/startup/startup_resource_manifest.json` through explicit, idempotent, fail-closed prepare APIs. World-entry gating remains deferred to Startup-3.
- UI-2 is integrated: management primary menu layout, board edit primary localization refresh, and management style construction moved from `UI.gd` into existing management helper/controllers; four synthetic visual gates match baseline.
- The pilot manifest now has 13 entries. It is still not a complete historical full-suite catalog.

## Stage three checkpoint

- Startup-3 is integrated: `WorldEntryPrepareGate` aggregates world-entry preparation for core DataHandler world data, routes, cell effects, and task modules before threaded world scene loading.
- World entry now stops and reports aggregated prepare errors instead of continuing with empty data. The gate intentionally does not load deferred weapon branch/passive data during title-to-world startup.
- UI-3 is integrated: `ModalUiController` now owns a declarative ordered registry for selection modals, including visibility, world-blocking, and cancellation capability. `UI.gd` delegates registered selection-modal cancellation to the controller and clears the registry on exit.
- Test infrastructure Batch 3 is integrated: `run_selected_tests.ps1` runs changed-path selection, Godot check-only with runtime/script error scanning, and isolated Workers for selected manifest entries in one command.
- Added `startup.world_entry_prepare_gate` to the pilot manifest. The pilot manifest now has 14 entries and remains representative rather than full historical coverage.

## Coordinator integration

- Verified range ownership before integration; no two ranges changed the same business file.
- No range changed `project.godot`, coordinator prompts, another range's tests, or another range's progress file.
- Registered the new UI, Player, and Startup scene entries after their paths stabilized.
- Did not add an Autoload, global event bus, service locator, or per-frame container allocation.
- Did not delete, move, compress, or rewrite any asset.
- No commits, pushes, or pull requests were created.

## Validation

- `git diff --check`: PASS.
- PowerShell parser for benchmark, selector, and Worker scripts: PASS.
- Selector contract self-test: PASS.
- Worker parser/process self-test: PASS.
- Selected runner self-test: PASS.
- Godot 4.7 `--headless --check-only --quit`: PASS.
- First-round 11 registered pilot scenes: PASS with isolated `GODOT_USER_HOME`.
- Current 13 registered pilot scenes through the Worker after Player-2B/UI-2/Startup-2B: PASS=13, FAIL=0, ERROR=0 with isolated process roots; shutdown diagnostics=19 retained as diagnostics; runtime errors=0. Result root: `test-results/worker-13-manifest-player2b`.
- Current 14 registered pilot scenes through the Worker after Batch 3: PASS=14, FAIL=0, ERROR=0 with isolated process roots; shutdown diagnostics=19 retained as diagnostics; runtime errors=0. Result root: `test-results/worker-14-manifest-batch3`.
- Selected world run through `run_selected_tests.ps1`: PASS=5, FAIL=0, ERROR=0; shutdown diagnostics=11; runtime errors=0. Result root: `test-results/batch3-selected-world-2`.
- UI-2 visual gate: 1280x720 and 1920x1080 in English and Simplified Chinese matched baseline on the non-headless Vulkan render path.
- Existing weapon smoke: PASS.
- Expected existing shutdown diagnostics remain on several scene tests: leaked CanvasItem/font/texture RIDs, ObjectDB instances, and 4 or 14 resources still in use.

Registered milestone scenes:

1. `cell.effect_runtime`
2. `ui.unified_modal_behavior`
3. `ui.task_module_dialog_controller`
4. `player.movement_system`
5. `player.auto_navigation`
6. `player.dash_movement_integration`
7. `player.active_skill_characterization`
8. `startup.resource_manifest_audit`
9. `startup.manifest_runtime_consumption`
10. `startup.baseline_probe`
11. `startup.world_entry_prepare_gate`
12. `weapon.numeric_module`
13. `world.player_assist_settings`
14. `world.threaded_world_load`

## Open risks and acceptance status

- Final Batch 2 validation used the project-standard Godot 4.7 binary available on this machine.
- The manifest is a 14-entry representative pilot, not a complete historical test inventory.
- `UI.gd` is 1599 lines and `Player.gd` is 1828 lines; final soft targets of approximately 600/700 lines are not yet reached.
- Startup manifests are runtime-consumed for the eight registered startup catalogs; world-entry prepare failure now gates title-to-world transition, while deferred branch/passive data remains out of title-to-world startup.
- Existing shutdown resource leaks remain visible and are not classified as runtime behavior failures.

## Next safe batches

1. Startup-4: rerun cold-import/hot-start/directed startup measurements and compare against Startup-1 baseline without broadening scope if gains are insufficient.
2. UI-4: move HUD refresh coordination behind behavior and refresh-count gates.
3. Test infrastructure: expand the pilot manifest before treating selected runs as full-suite coverage.
4. Asset pipeline: only after explicit approval, handle the single orphan `.import` as its own reversible batch.
