# Test Infrastructure Progress

## Completed batches

### 2026-07-02 — Batch 1: manifest contract and conservative selector

- Added a versioned declarative manifest with five representative scene gates across cell, UI, weapon, and world behavior.
- Added an ordered source-to-domain map with explicit core, uncertain, ignored, and unknown-path handling.
- Added an affected-test selector with explicit test inclusion and human-readable or JSON reasons.
- Added standalone selector contract tests for empty, single-domain, multi-domain, core, manifest, uncertain, unknown, docs-only, and explicit-selection cases.
- Documented the pilot status and registration workflow. The manifest is not yet a replacement for existing manual full-suite gates.

### 2026-07-02 — Batch 2: isolated limited-parallel Worker

- Added the Worker runner around the declarative manifest with retained stdout/stderr logs, reproduction commands, timeout handling, and conservative scheduling.
- Each Godot process receives isolated `GODOT_USER_HOME`, `APPDATA`, and `LOCALAPPDATA` roots.
- Only tests marked `parallel_safe=true` and `writes_user_data=false` can run concurrently; exclusive entries serialize.
- Fixed status classification: a scene with an explicit `PASS` plus known Godot shutdown leak diagnostics remains `PASS` with retained shutdown diagnostics, while actual runtime errors still classify as `ERROR`.
- Added Worker self-tests and fixtures for success, failure, timeout, shutdown diagnostics, runtime errors, and user-data isolation.

### 2026-07-02 — Batch 3: selector-to-Worker orchestration

- Added `tests/infrastructure/run_selected_tests.ps1`.
- The wrapper resolves changed paths, runs `Select-AffectedTests`, runs Godot `--check-only`, scans check-only output for runtime/script errors, and invokes isolated Workers for selected manifest entries.
- Supports `-ChangedPath`, `-BaseRef`, `-IncludeTest`, `-ManifestPath`, `-SourceMapPath`, `-GodotPath`, `-Jobs`, `-OutputRoot`, `-SkipCheckOnly`, and `-Json`.
- Empty or docs-only selections still run check-only by default and skip Worker execution.
- Added `tests/infrastructure/tests/test_selected_runner_test.ps1`, which builds a temporary fixture manifest and verifies changed-path selection through a real Worker run.

### 2026-07-02 - Batch 4: UI gate registration expansion

- Registered five existing UI scene-backed tests: `ui.hud_dirty_refresh`, `ui.player_health_meter_contract`, `ui.skill_energy_meter_contract`, `ui.combat_resource_meter_contract`, and `ui.module_fit_display_contract`.
- Manifest entries now cover 19 representative gates.
- Catalog status remains `pilot`.
- Fixed Windows PowerShell compatibility in the Worker scripts: default manifest/source-map paths are resolved after `$PSScriptRoot` is available, process arguments fall back to `ProcessStartInfo.Arguments`, and timeout termination uses `taskkill /T /F` when needed.

### 2026-07-02 - Stage 1: historical scene manifest registration

- Registered 29 additional Worker-compatible scene-backed tests across UI, Weapon, World, Reward, Cell, Spawn, and Enemy domains.
- Manifest entries now cover 48 scene-backed gates.
- `catalog_status` remains `pilot`; manifest `full` mode means every registered entry, not every historical `tests/scenes/**/*.tscn` file.
- Startup and Combat had no remaining unregistered scene-backed tests in this pass.
- Kept 10 scene files unregistered with explicit reasons: one Player fixture scene, one non-terminating UI scene, one non-headless visual UI gate, and seven currently failing or runtime-erroring historical gates.

### 2026-07-02 - Stage 2: manifest status review

- Rechecked all `tests/scenes/**/*.tscn` paths against the 48-entry manifest.
- Rechecked all `tests/headless/**/*.gd` runner scripts for missing scene wrappers.
- Did not upgrade `catalog_status`; it remains `pilot` because 10 scene-backed files are still unregistered and 23 runner-only scripts still lack scene wrappers or manifest entries.
- Full 48-entry Worker candidate passed, so the registered pilot set is healthy, but it is not a complete test-directory entrypoint.

### 2026-07-02 - Stage 3: Player camera gate registration

- Added `player.camera_system` as a focused scene-backed Player gate while continuing Player slimming.
- Manifest entries now cover 49 Worker-compatible gates.
- `catalog_status` remains `pilot`; manifest `full` mode still means every registered entry, not every historical `tests/scenes/**/*.tscn` file.
- The unresolved historical inventory remains 10 scene-backed files and 23 runner-only scripts outside the manifest.

### 2026-07-02 - Stage 7: final closure report

- Final report path: `docs/reports/project_slimming_completion_report.md`.
- Final manifest count remains 49 Worker-compatible entries.
- `catalog_status` remains `pilot`; a Worker `full` run still means every registered manifest entry, not every historical test entrypoint in the repository.
- Domain counts at closure: `cell=3`, `enemy=1`, `player=5`, `reward=6`, `spawn=2`, `startup=4`, `ui=14`, `weapon=9`, `world=5`.
- No Stage 7 infrastructure script or manifest change was made.

## Metrics

- Infrastructure files: 0 -> 4 implementation/configuration files plus 1 self-test.
- Registered manifest entries: 0 -> 5 representative gates.
- Worker files: 0 -> 1 runner, 1 Worker module, 1 self-test, and 4 fixtures.
- Registered manifest entries after coordinator integration: 13 representative gates.
- Registered manifest entries after Batch 4: 19 representative gates.
- Registered manifest entries after Stage 1 registration: 48 Worker-compatible gates.
- Registered manifest entries after Stage 2 status review: 48 Worker-compatible gates; status remains `pilot`.
- Registered manifest entries after Stage 3 Player camera gate: 49 Worker-compatible gates; status remains `pilot`.
- Explicit source-domain rules: 0 -> 32.
- Automated selector scenarios: 0 -> 10.
- Current discovered inventory: 76 headless `.gd` scripts and 59 scene `.tscn` entries; 10 scene-backed files and 23 runner-only scripts remain outside the manifest.

## Tests and results

- `pwsh -NoProfile -File tests/infrastructure/tests/test_selection_test.ps1`: PASS.
- Selector CLI single-domain output: PASS; selected only `ui.unified_modal_behavior` with reasons.
- Selector CLI `project.godot` output: PASS; returned `full` and all five registered entries.
- Godot 4.7 isolated-worktree import: PASS; populated only this worktree's ignored `.godot` cache.
- Godot 4.7 `--headless --path . --check-only --quit`: PASS after import.
- Worker parser/process self-test: PASS.
- Selected runner self-test: PASS.
- Full 13-entry Worker manifest after Batch 2 integration: PASS=13, FAIL=0, ERROR=0, shutdown diagnostics=19 retained as diagnostics, runtime errors=0.
- Full 14-entry Worker manifest after Batch 3 integration: PASS=14, FAIL=0, ERROR=0, shutdown diagnostics=19 retained as diagnostics, runtime errors=0.
- Selected world run through `run_selected_tests.ps1`: PASS=5, FAIL=0, ERROR=0, shutdown diagnostics=11, runtime errors=0.
- Worker parser/process self-test after Windows PowerShell compatibility fix: PASS.
- Selected UI run after Batch 4 registration: PASS=19, FAIL=0, ERROR=0, shutdown diagnostics=26, runtime errors=0.
- `git diff --check`: PASS.
- First import rewrote two generated `data/localization/rest_area_shop_update.*.translation` files. Those out-of-scope changes were restored and are excluded from this batch.
- Stage 1 UI registration batch: PASS=7, FAIL=0, ERROR=0, shutdown diagnostics=17, runtime errors=0. Result root: `test-results/manifest-registration-ui-final`.
- Stage 1 Weapon registration batch: PASS=8, FAIL=0, ERROR=0, shutdown diagnostics=12, runtime errors=0. Result root: `test-results/manifest-registration-weapon-final`.
- Stage 1 World registration batch: PASS=3, FAIL=0, ERROR=0, shutdown diagnostics=8, runtime errors=0. Result root: `test-results/manifest-registration-world-final`.
- Stage 1 Reward registration batch: PASS=6, FAIL=0, ERROR=0, shutdown diagnostics=11, runtime errors=0. Result root: `test-results/manifest-registration-reward-final`.
- Stage 1 Cell registration batch: PASS=2, FAIL=0, ERROR=0, shutdown diagnostics=0, runtime errors=0. Result root: `test-results/manifest-registration-cell-final`.
- Stage 1 Spawn registration batch: PASS=2, FAIL=0, ERROR=0, shutdown diagnostics=0, runtime errors=0. Result root: `test-results/manifest-registration-spawn`.
- Stage 1 Enemy registration batch: PASS=1, FAIL=0, ERROR=0, shutdown diagnostics=0, runtime errors=0. Result root: `test-results/manifest-registration-enemy`.
- Stage 1 per-batch validation also reran manifest count, selector self-test, Worker parser/process self-test, and `git diff --check`.
- Stage 1 full 48-entry Worker manifest: PASS=48, FAIL=0, ERROR=0, shutdown diagnostics=74, runtime errors=0. Result root: `test-results/manifest-registration-full-48`.
- Stage 2 full manifest candidate: PASS=48, FAIL=0, ERROR=0, shutdown diagnostics=74, runtime errors=0. Result root: `test-results/manifest-full-candidate`.
- Stage 3 focused Player camera gate: PASS=1, FAIL=0, ERROR=0, shutdown diagnostics=0, runtime errors=0. Result root: `test-results/player-camera-system-gate-2`.
- Stage 3 selected Player run through `run_selected_tests.ps1`: PASS=49, FAIL=0, ERROR=0, shutdown diagnostics=74, runtime errors=0. Result root: `test-results/player-slimming-camera-config-final-2`.
- Stage 3 post-run process check found leftover headless Godot Worker processes after the PASS summary; all project `godot.windows.opt.tools.64.exe` processes were terminated and the final process check was empty.

## Known risks

- `catalog_status` is `pilot`; a `full` result currently means every registered manifest entry, not every historical active test.
- Domain dependencies are intentionally coarse. Broad data, asset, shader, object, Autoload, core facade, and unknown paths force full fallback.
- Selector-to-Worker orchestration uses the registered Worker-compatible pilot manifest; it is not full historical test coverage until the 10 still-unregistered scene files and 23 runner-only scripts are resolved or explicitly retired.

## Next recommended batch

Continue expanding the manifest beyond representative pilot coverage before treating selected runs as a full-suite replacement.
