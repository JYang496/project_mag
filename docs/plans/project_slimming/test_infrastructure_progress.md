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

## Metrics

- Infrastructure files: 0 -> 4 implementation/configuration files plus 1 self-test.
- Registered manifest entries: 0 -> 5 representative gates.
- Worker files: 0 -> 1 runner, 1 Worker module, 1 self-test, and 4 fixtures.
- Registered manifest entries after coordinator integration: 13 representative gates.
- Explicit source-domain rules: 0 -> 32.
- Automated selector scenarios: 0 -> 10.
- Existing discovered inventory remains unchanged: 64 headless `.gd` scripts and 47 scene `.tscn` entries.

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
- `git diff --check`: PASS.
- First import rewrote two generated `data/localization/rest_area_shop_update.*.translation` files. Those out-of-scope changes were restored and are excluded from this batch.

## Known risks

- `catalog_status` is `pilot`; a `full` result currently means every registered pilot entry, not every historical active test.
- Domain dependencies are intentionally coarse. Broad data, asset, shader, object, Autoload, core facade, and unknown paths force full fallback.
- Selector-to-Worker orchestration uses the representative pilot manifest; it is not full historical test coverage.

## Next recommended batch

Expand the manifest beyond representative pilot coverage before treating selected runs as a full-suite replacement.
