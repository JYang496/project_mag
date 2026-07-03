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

## Stage four checkpoint

- Startup-4 measurements were recorded in `startup_progress.md`. Hot-start resource load count improved from 258 to 215; hot-start time regressed 4.8%, below the 5% rollback threshold, and directed startup improved 7.5%. Cold import was not accepted as a clean signal because the worktree contained broad unrelated changes.
- UI-4 is accepted through the existing HUD dirty-refresh gate instead of a new refresh system. `ui.hud_dirty_refresh` now belongs to the manifest, alongside four existing UI meter/fit contract gates.
- Player-3 took the smallest safe cleanup slice: removed dead Player-owned elite-hit helper wrappers after confirming `PlayerDamageReactionSystem` owns the only live call path.
- Test infrastructure Batch 4 expands the pilot manifest from 14 to 19 representative entries. It is still a pilot manifest, not a complete historical inventory.
- Asset pipeline Batch 2 removed only the audited orphan import sidecar `asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`; no source asset, font, ZIP, image, or importer setting was changed.
- Stage 4 baseline rechecked on 2026-07-02 at `f425b1fb2ed10da837372cd643c2f1c24e0086f2`; the remaining uncommitted worktree changes were limited to completion prompt/handoff split files.

## Completion Stage 1 checkpoint

- Registered 29 additional Worker-compatible historical scene-backed tests, bringing `tests/infrastructure/test_manifest.json` from 19 to 48 entries.
- Registration was split by domain: UI, Weapon, World, Reward, Cell, Spawn, and Enemy. Startup and Combat had no remaining unregistered scene-backed tests.
- `catalog_status` remains `pilot`; manifest `full` mode means every registered entry, not every historical scene under `tests/scenes`.
- Ten scene files remain unregistered with explicit reasons in `tests/README.md`: fixture-only, non-terminating, non-headless visual, current assertion failures, missing doc dependency, or runtime script errors.

## Completion Stage 2 checkpoint

- Rechecked all scene-backed tests and runner scripts before changing manifest status.
- Did not upgrade `catalog_status`: 10 scene-backed files remain unregistered and 23 runner-only scripts still lack scene wrappers or manifest entries.
- The 48-entry registered manifest is healthy as a pilot set, but it is not yet a complete test-directory entrypoint.

## Completion Stage 3 checkpoint

- Continued Player slimming with one behavior-protected camera/rest-area slice.
- Added `PlayerCameraConfig` and changed `PlayerCameraSystem` to receive explicit camera config plus vision updates instead of storing a Player owner or reading Player fields dynamically.
- Added `player.camera_system` to the pilot manifest, bringing registered Worker-compatible gates from 48 to 49 while keeping `catalog_status: "pilot"`.
- `Player.gd`: 1822 -> 1813 lines for this camera/rest-area slice. The accepted reduction is Player-owned camera state and reverse dependency direction, not the full Player line-count target.

## Completion Stage 4 checkpoint

- Continued UI slimming with one behavior-protected HUD refresh coordination slice.
- Added `HudRefreshController` to own HUD dirty flags, refresh ordering, continuous refresh cadence, and HUD refresh debug counters.
- `UI.gd` now keeps HUD refresh compatibility entrypoints as delegating facades, while `UiDirtySignalController` routes HUD invalidation through narrow mark methods instead of writing HUD dirty state directly.
- `UI.gd`: 1599 -> 1588 lines.

## Completion Stage 5 checkpoint

- Rechecked the asset-pipeline follow-up gate for one category only: `asset/images/characters/characters_move.zip`.
- No asset was deleted, moved, compressed, or rewritten because ZIP archival has not been explicitly approved.
- Current evidence still classifies the ZIP as a repository archival candidate: no `.import`/`.uid`, no runtime path reference outside docs/prompts, no export preset in the checkout, and ZIP file hashes match the 42 already-extracted runtime frames.
- No cold-import benefit was claimed; ZIP has no importer and needs a separate benchmark if future work wants to claim startup/import impact.

## Completion Stage 6 checkpoint

- Ran the final startup benchmark after Player/UI/manifest/asset closure. Raw JSON: `test-results/startup-final-benchmark-full.json`.
- Fixed `tools/benchmark_startup_loading.ps1` so the documented repo-root command works under Windows PowerShell and verbose Godot output is parsed from redirected log files instead of in-memory native pipes.
- Stage 6 benchmark on Godot `4.6.1.stable.steam.14d19694e`: cold import 48,455 ms, hot start median 5,056 ms, directed startup median 7,090 ms.
- Loaded resource counts stayed aligned with the post-manifest shape: cold 66, hot 215, directed 353.
- Runtime errors remained 0 for cold import, hot start, directed startup, and the selected startup validation run.
- Shutdown diagnostics stayed separate from runtime errors: benchmark directed runs reported 50 error-class shutdown diagnostics plus 10 warnings across 5 runs; selected 49-entry validation reported 74 shutdown diagnostics and 0 runtime errors.
- No further startup optimization was attempted from this checkpoint; remaining startup risk is cleanup/leak diagnostics, not a new manifest target.

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
- Stage 4 selected UI run through `run_selected_tests.ps1`: PASS=19, FAIL=0, ERROR=0; shutdown diagnostics=26; runtime errors=0. Result root: `test-results/slimming-stage4-selected-ui-final`.
- Stage 4 focused Worker run for UI HUD/meter/fit gates plus player active-skill characterization: PASS=6, FAIL=0, ERROR=0; shutdown diagnostics=7; runtime errors=0. Result root: `test-results/slimming-stage4-focused`.
- Stage 4 checkpoint revalidation on 2026-07-02: `git diff --check`, selector self-test, Worker parser/process self-test with the project Godot 4.7 binary, and Godot `--headless --path . --check-only --quit` all PASS; no residual `godot.windows.opt.tools.64.exe` worker process was found.
- Completion Stage 1 registration batches: UI PASS=7, Weapon PASS=8, World PASS=3, Reward PASS=6, Cell PASS=2, Spawn PASS=2, Enemy PASS=1; all final domain batches had FAIL=0 and ERROR=0.
- Completion Stage 1 per-batch validation reran manifest count, selector self-test, Worker parser/process self-test, and `git diff --check`; final manifest count is 48 with no duplicate ids or paths.
- Completion Stage 1 full 48-entry Worker manifest: PASS=48, FAIL=0, ERROR=0; shutdown diagnostics=74; runtime errors=0. Result root: `test-results/manifest-registration-full-48`.
- Completion Stage 2 full manifest candidate: PASS=48, FAIL=0, ERROR=0; shutdown diagnostics=74; runtime errors=0. Result root: `test-results/manifest-full-candidate`.
- Completion Stage 3 focused Player camera gate: direct `res://tests/scenes/player/player_camera_system_test.tscn` PASS; Worker entry `player.camera_system` PASS=1, FAIL=0, ERROR=0, runtime errors=0 inside `test-results/player-slimming-camera-focused`.
- Completion Stage 3 required selected command was executed with `-ChangedPath 'Player/Mechas/scripts/Player.gd' -Jobs 2`, but it selected the full 49-entry pilot catalog and did not produce an acceptable green run: first result `test-results/player-slimming-camera` was PASS=48, FAIL=0, ERROR=1 due to unrelated `reward.loot_rarity`; later reruns showed unrelated `exit code -1` runner/process failures while `player.camera_system` stayed PASS.
- Completion Stage 4 selected UI run through `run_selected_tests.ps1 -ChangedPath 'UI/scripts/UI.gd'`: PASS=49, FAIL=0, ERROR=0; shutdown diagnostics=74; runtime errors=0. Result root: `test-results/ui-slimming-hud-refresh`.
- Completion Stage 5 ZIP audit validation: `git diff --check` PASS; Godot `--headless --path . --check-only --quit` PASS. No startup or UI visual gate was required because no resource or runtime path changed.
- Completion Stage 6 final startup benchmark: PASS. Cold import 48,455 ms; hot start median 5,056 ms; directed startup median 7,090 ms; runtime errors=0; directed shutdown diagnostics kept separate from runtime errors. Result JSON: `test-results/startup-final-benchmark-full.json`.
- Completion Stage 6 selected startup validation: `run_selected_tests.ps1 -ChangedPath 'data/startup/startup_resource_manifest.json' -Jobs 2` PASS=49, FAIL=0, ERROR=0; shutdown diagnostics=74; runtime errors=0. Result root: `test-results/startup-final-benchmark`.
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
15. `ui.hud_dirty_refresh`
16. `ui.player_health_meter_contract`
17. `ui.skill_energy_meter_contract`
18. `ui.combat_resource_meter_contract`
19. `ui.module_fit_display_contract`
20. `cell.task_module_runtime`
21. `cell.offense_kill_objective_global_count`
22. `ui.branch_select_panel`
23. `ui.controls_hint_view`
24. `ui.management_polish`
25. `ui.shop_sell_flow`
26. `ui.temporary_module_settlement_dialog`
27. `ui.upgrade_preview_refresh`
28. `ui.weapon_selector_layer`
29. `enemy.support_behavior`
30. `weapon.auto_fire_switch`
31. `weapon.dash_blade_offhand_auto_attack`
32. `weapon.on_hit_module_lifecycle`
33. `weapon.player_stat_module`
34. `weapon.synergy_module`
35. `weapon.smoke`
36. `weapon.auto_fuse`
37. `weapon.fire_feedback`
38. `world.rest_area_task_management_blocking`
39. `world.secondary_menu_world_blocking`
40. `world.startup_feature_loadout`
41. `reward.battle_drop_storage`
42. `reward.equipment_pickup_queue`
43. `reward.loot_rarity`
44. `reward.draft_runtime_contract`
45. `reward.draft_simulation_report`
46. `reward.temporary_module_lifecycle`
47. `spawn.ranged_spawn_limits`
48. `spawn.boundary_projection`
49. `player.camera_system`

## Open risks and acceptance status

- Final Batch 2 validation used the project-standard Godot 4.7 binary available on this machine.
- The manifest is a 49-entry Worker-compatible pilot, not a complete historical test inventory until the 10 still-unregistered scene files and 23 runner-only scripts are resolved or explicitly retired.
- `UI.gd` is 1588 lines and `Player.gd` is 1813 lines; final soft targets of approximately 600/700 lines are not yet reached.
- Startup manifests are runtime-consumed for the eight registered startup catalogs; world-entry prepare failure now gates title-to-world transition, while deferred branch/passive data remains out of title-to-world startup.
- Existing shutdown resource leaks remain visible and are not classified as runtime behavior failures.

## Completion Stage 7 checkpoint

- Added the independent completion report: `docs/reports/project_slimming_completion_report.md`.
- Recorded the final report baseline from `git status --short --branch` and `git rev-parse HEAD`: branch `master...origin/master`, HEAD `f425b1fb2ed10da837372cd643c2f1c24e0086f2`.
- Current manifest remains `catalog_status: "pilot"` with 49 registered Worker-compatible entries.
- Final line-count snapshot: `UI.gd` 1802 plan-baseline lines -> 1588 final lines; `Player.gd` 1786 plan-baseline lines -> 1813 final lines.
- Stage 7 made documentation-only changes and did not change business code.
- Post-plan `ponytail` items are documented as optional follow-ups, not as unfinished acceptance blockers.
- Stage 7 final validation: `git diff --check` PASS; Godot `--headless --path . --check-only --quit` PASS; full 49-entry Worker run PASS=49, FAIL=0, ERROR=0, shutdown diagnostics=74, runtime errors=0 in `test-results/project-slimming-final`.

## Next safe batches

1. Test infrastructure: resolve or retire the 10 still-unregistered scene files and 23 runner-only scripts before changing `catalog_status`.
2. Player: continue with a behavior-protected incoming-damage or damage-pipeline slice; do not chase the 700-line target without a focused gate.
3. UI: continue with behavior-protected localization refresh or pause/settings UI extraction; use a visual baseline only if layout changes.
4. Asset pipeline: leave OTF, ZIP, and image cleanup untouched until each has its own explicit approval and visual/import recovery gate; ZIP archival also needs export/manufacturing-source approval before any move/delete.
