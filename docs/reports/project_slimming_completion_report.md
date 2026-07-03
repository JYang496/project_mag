# Project Slimming Completion Report

Date: 2026-07-02

## Scope and Baseline

- Repository: `D:\Godot Projects\project_mag`
- Branch at start of Stage 7: `master...origin/master`
- HEAD at start of Stage 7: `f425b1fb2ed10da837372cd643c2f1c24e0086f2`
- Final report scope: document the completed slimming plan, preserve unresolved risks, and identify low-risk `ponytail` follow-ups for after this plan.
- No business-code change was made in Stage 7.

## Completed Batches

1. UI-1 extracted task-module dialog ownership into `TaskModuleDialogController`.
2. UI-2 moved management menu layout, style, and localization refresh responsibilities out of `UI.gd`.
3. UI-3 moved selection-modal behavior into `ModalUiController`'s declarative registry.
4. UI-4 registered existing HUD and meter contract gates in the Worker manifest.
5. UI-5 moved HUD dirty flags, refresh ordering, cadence, and debug counters into `HudRefreshController`.
6. Player-1 removed `PlayerMovementSystem`'s Player owner dependency and introduced typed movement frame input/result objects.
7. Player-2A/2B split active-skill runtime responsibility into energy, player-skill, and weapon-action helpers.
8. Player-3 removed dead Player-owned damage-reaction wrapper methods.
9. Player-4 moved camera/rest-area configuration into `PlayerCameraConfig` plus explicit `PlayerCameraSystem` inputs.
10. Test Infrastructure Batch 1 introduced the pilot manifest, source-domain map, selector, CLI, and selector tests.
11. Test Infrastructure Batch 2 added isolated limited-parallel Worker execution.
12. Test Infrastructure Batch 3 added selector-to-Worker orchestration via `run_selected_tests.ps1`.
13. Test Infrastructure Batch 4 expanded UI gate registration.
14. Completion Stage 1 registered 29 additional Worker-compatible historical scene-backed tests.
15. Completion Stage 2 reviewed manifest completeness and intentionally kept `catalog_status` as `pilot`.
16. Completion Stage 3 registered the focused Player camera gate.
17. Startup-1 added repeatable cold-import, hot-start, and directed-startup benchmark tooling.
18. Startup-2A/2B moved eight startup catalogs to explicit manifest consumption.
19. Startup-3 added `WorldEntryPrepareGate` for world-entry prepare aggregation.
20. Startup-3B stopped eager prepare in selected Autoload `_ready()` paths.
21. Startup-4 measured post-manifest startup behavior.
22. Startup-5/6 reran final startup benchmark and fixed the benchmark script's repo-root Windows invocation.
23. Asset-1 audited tracked assets, references, imports, duplicate hashes, fonts, and ZIP contents.
24. Asset-2 removed only the audited orphan sidecar `asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`.
25. Asset-3 rechecked `asset/images/characters/characters_move.zip` as an archival candidate and made no asset change.
26. Stage 7 produced this completion report and appended final closure notes to the progress files.

## UI.gd and Player.gd Results

| File | Plan baseline commit `51ec0972` | HEAD before Stage 7 | Current final | Net from plan baseline | Net from Stage 7 start |
| --- | ---: | ---: | ---: | ---: | ---: |
| `UI/scripts/UI.gd` | 1802 lines | 1599 lines | 1588 lines | -214 | -11 |
| `Player/Mechas/scripts/Player.gd` | 1786 lines | 1805 lines | 1813 lines | +27 | +8 |

Responsibility changes:

- `UI.gd` no longer owns task-module dialog state, management menu style/layout construction, selection-modal registry logic, or HUD refresh dirty-state coordination. It still acts as the scene-level adapter and compatibility facade for existing callers.
- `Player.gd` no longer acts as the movement calculation owner, active-skill implementation container, dead elite-hit wrapper owner, or camera-system reverse dependency source. It still owns the CharacterBody2D engine boundary, exported tuning fields, public facades, and explicit config sync into extracted systems.
- `Player.gd` remains above the long-term soft target because this plan prioritized dependency direction and behavior gates over blind line-count removal.

## Manifest Final State

- File: `tests/infrastructure/test_manifest.json`
- Final entry count: 49
- `catalog_status`: `pilot`
- Status semantics: `pilot` means this is the registered Worker-compatible catalog only. A "full" Worker run means all registered manifest entries, not every historical `tests/scenes/**/*.tscn` file or every runner-only script.
- Domain counts: `cell=3`, `enemy=1`, `player=5`, `reward=6`, `spawn=2`, `startup=4`, `ui=14`, `weapon=9`, `world=5`.
- Remaining inventory gap: 10 scene-backed files and 23 runner-only scripts remain outside the manifest until resolved, wrapped, or explicitly retired.

## Startup Benchmark Comparison

Final benchmark artifact: `test-results/startup-final-benchmark-full.json`

- Godot: `4.6.1.stable.steam.14d19694e`
- Benchmark commit recorded in JSON: `f425b1fb2ed10da837372cd643c2f1c24e0086f2`
- Hot-start scene: `res://World/Start.tscn`
- Directed scene: `res://tests/scenes/startup/startup_baseline_probe.tscn`

| Metric | Startup-1 baseline | Startup-4 confirmed retest | Stage 6 final | Change vs Startup-1 | Change vs Startup-4 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cold import | 61,379 ms | not used as clean signal | 48,455 ms | -21.1% | not compared |
| Hot start median | 8,267 ms | 8,663 ms | 5,056 ms | -38.8% | -41.6% |
| Directed startup median | 12,304 ms | 11,384 ms | 7,090 ms | -42.4% | -37.7% |
| Hot-start loaded resources | 258 | 215 | 215 | -43 | 0 |
| Directed loaded resources | 353 | 353 | 353 | 0 | 0 |
| Runtime errors | 0 | 0 | 0 | unchanged | unchanged |

Final benchmark raw range:

- Cold import: `48,455 ms`, 66 unique resources, 425 imported cache files, 0 runtime errors.
- Hot start: `5,054 / 5,055 / 5,057 / 5,065 / 5,056 ms`, median `5,056 ms`, 215 median unique resources, 0 runtime errors, 0 shutdown diagnostics.
- Directed startup: `7,063 / 7,091 / 7,068 / 7,090 / 7,100 ms`, median `7,090 ms`, 353 median unique resources, 0 runtime errors, 50 shutdown diagnostics and 10 warnings across 5 runs.

## Asset Pipeline Final State

Deleted:

- `asset/images/weapons/Remove_background_to_create_transparent_PNG-1777246945516.png.import`

Retained:

- All source assets.
- All fonts, including the active Thin TTF and the unreferenced Regular OTF.
- `asset/images/characters/characters_move.zip`.
- PNG files and importer settings.

Evidence and status:

- `characters_move.zip` is still only an archival candidate. It has no `.import` or `.uid`, no runtime path reference outside docs/prompts, and its 42 PNG entries match the already-extracted runtime frames.
- No cold-import or runtime gain is claimed for ZIP removal because no ZIP move/delete was approved and no ZIP-specific benchmark was run.
- No asset folder diff is currently pending from Stage 7.

## Validation Commands and Results

Pre-Stage 7 required commands:

```powershell
git status --short --branch
git rev-parse HEAD
```

Result: PASS. Branch was `master...origin/master`; HEAD was `f425b1fb2ed10da837372cd643c2f1c24e0086f2`. The worktree already contained the slimming-stage changes and untracked generated/prompt/report artifacts; Stage 7 did not revert them.

Previously recorded plan validations:

- `git diff --check`: PASS in Stage 4, Stage 5, Stage 6, and per-batch registration checks.
- Godot `--headless --path . --check-only --quit`: PASS in the UI, Player, Startup, Asset, and Stage 6 gates.
- Completion Stage 1 full 48-entry Worker manifest: `PASS=48 FAIL=0 ERROR=0`, shutdown diagnostics 74, runtime errors 0.
- Completion Stage 2 full manifest candidate: `PASS=48 FAIL=0 ERROR=0`, shutdown diagnostics 74, runtime errors 0.
- Completion Stage 3 selected Player run: `PASS=49 FAIL=0 ERROR=0`, shutdown diagnostics 74, runtime errors 0.
- Completion Stage 4 selected UI run: `PASS=49 FAIL=0 ERROR=0`, shutdown diagnostics 74, runtime errors 0.
- Completion Stage 6 selected startup validation: `PASS=49 FAIL=0 ERROR=0`, shutdown diagnostics 74, runtime errors 0.
- Completion Stage 6 final startup benchmark: PASS, runtime errors 0.

Stage 7 final validation:

```powershell
git diff --check
```

Result: PASS, exit code 0, no whitespace/error output.

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Result: PASS, exit code 0, no check-only error output.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/infrastructure/run_test_workers.ps1 -GodotPath 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' -Jobs 2 -OutputRoot 'test-results\project-slimming-final'
```

Result: PASS. Summary `PASS=49 FAIL=0 ERROR=0 SHUTDOWN_DIAGNOSTICS=74 RUNTIME_ERRORS=0`. Output root: `test-results\project-slimming-final`.

## Remaining Risks

1. `tests/infrastructure/test_manifest.json` remains `catalog_status: "pilot"` because 10 scene-backed files and 23 runner-only scripts are still outside the manifest. This is a concrete test-inventory gap, not a runtime failure.
2. Existing Godot shutdown diagnostics remain visible in directed startup and Worker runs: leaked texture/font RIDs, ObjectDB cleanup warnings, `Cannot get path of node as it is not in a scene tree`, and resources still in use at exit. Runtime errors remain 0, but cleanup should be a dedicated follow-up.
3. `UI/scripts/UI.gd` is still 1588 lines and `Player/Mechas/scripts/Player.gd` is still 1813 lines. The long-term soft targets are not met; further work should move one behavior-protected responsibility at a time.
4. `asset/images/characters/characters_move.zip` remains in `res://` until an explicit archive/move/delete decision is approved with restore instructions and a ZIP-specific benchmark if startup/import benefit is claimed.
5. Font cleanup remains blocked: the active TTF and unreferenced OTF have different internal styles, so replacement/removal needs visual coverage.
6. Startup benchmark comparisons are local-machine signals. Stage 6 used Steam Godot `4.6.1`, while earlier notes reference `4.6.2` and project feature `4.7`; cross-version attribution should not be overclaimed.

## Ponytail Follow-Ups After This Plan

These are deliberately not part of Stage 7 because the plan is complete and the cheapest safe action is to document them:

1. Retire or wrap the 10 unregistered scene files and 23 runner-only scripts before changing `catalog_status` from `pilot`.
2. Treat shutdown diagnostics as a cleanup-only batch with one reproduction command and one acceptance rule: runtime behavior must stay PASS while diagnostics shrink.
3. Archive `characters_move.zip` only after explicit approval; keep the restore note and SHA-256 with the move.
4. Continue `UI.gd` slimming only through an already-covered slice such as localization refresh or pause/settings UI ownership.
5. Continue `Player.gd` slimming only through a focused gate such as incoming damage reaction or damage-profile ownership.
6. Do not create new abstractions for line-count targets alone; move code only when a current responsibility boundary and test gate already exist.
