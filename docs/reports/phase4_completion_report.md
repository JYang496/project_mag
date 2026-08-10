# Phase 4 Completion Report

## Outcome

Phase 4 is implemented and verified. The project now has versioned,
deterministic performance results; 80/160/240 scale baselines; spawn, steady,
bulk-cleanup, VFX, pool and second-battle workloads; runtime counters; a
large-file ratchet; responsibility extraction from large owners; and retained
machine-readable artifacts.

## Implemented Components

- `tests/infrastructure/performance_result.gd`
  - versioned result schema;
  - raw samples;
  - average, p95, p99 and maximum calculation;
  - explicit `null` for unsupported counters.
- `tests/scenes/performance/phase4_benchmark_suite.*`
  - deterministic 80/160/240 spawn workloads;
  - dense steady registry-query workloads;
  - 80-entity bulk cleanup;
  - identical first/second battle replay;
  - object-pool reuse workload;
  - JSON output and deterministic position signatures.
- `tests/scenes/performance/combat_vfx_stress_test.gd`
  - full versus reduced-control VFX workload;
  - service cap/pool metrics;
  - machine-readable VFX result.
- `tools/run_phase4_baselines.ps1`
  - ten-run isolated Worker execution;
  - retained raw results;
  - median/min/max p99 aggregation;
  - deterministic signature audit.
- `tools/audit_architecture_budgets.ps1`
  - nonblank line budgets;
  - unbudgeted/over-budget failures;
  - long-function review report.
- `tools/architecture_budgets.json`
  - checked-in ratchet ceilings for all current runtime scripts over 800
    nonblank lines.

## Runtime Instrumentation

- `EnemyRegistry` query, candidate and bucket metrics are consumed by the
  benchmark suite.
- `ObjectPool` now reports requests, hits, misses, releases, invalid cached
  objects, capacity discards, available objects and in-use objects.
- `EnemySpawner` owns a dedicated `SpawnPerformanceMetrics` collaborator and
  exposes reset/snapshot APIs without putting benchmark policy into spawn
  decisions.
- VFX services expose active, pooled and capped-instance metrics used by the
  presentation stress baseline.
- Benchmark-owned cleanup counters report created/freed nodes while registry
  state proves cleanup completion. Unsupported physics contacts remain `null`,
  not a misleading zero.

## Architecture Ratchet and Extractions

Two large-owner responsibility migrations are present in the Phase 4 baseline:

1. Reward-card parsing and display assembly moved out of
   `reward_selection_panel.gd`, reducing it from roughly 1310 to 910 nonblank
   lines.
2. Contract beacon/objective point selection moved out of
   `enemy_spawner.gd` into `contract_objective_point_planner.gd`. After Phase 4
   metrics were added, the spawner ceiling ratcheted from 1322 to 1278 nonblank
   lines.

The architecture audit currently reports no budget violations. Long functions
are review findings rather than hard failures during this initial calibration
cycle.

## Ten-Run Baseline

Revision: `6945a770` plus the current working-tree changes.

| Scenario | Median p99 | Observed p99 range |
|---|---:|---:|
| Spawn burst 80 | 1.152 ms | 1.115–1.207 ms |
| Spawn burst 160 | 2.340 ms | 2.255–2.426 ms |
| Spawn burst 240 | 3.454 ms | 3.367–7.348 ms |
| Dense steady 80 | 6.939 ms | 6.919–7.063 ms |
| Dense steady 160 | 6.971 ms | 6.918–7.283 ms |
| Dense steady 240 | 6.938 ms | 6.925–7.309 ms |
| Bulk cleanup 80 | 6.903 ms | 6.872–6.924 ms |
| First/second replay 80 | 6.928 ms | 6.916–6.965 ms |

All position signatures were stable across ten isolated runs. The captured
first/second replay ratio was approximately 1.0 and both battles restored an
empty registry after cleanup.

These are diagnostic registry-probe workloads, not claims about full-game FPS
on every hardware configuration.

## VFX Finding

The full presentation stress requested 780 combined hit, muzzle, death and
ground effects from 240 input events. Setup took approximately 57.6 ms in the
captured run, versus approximately 0.01 ms for the reduced control workload.
All service caps remained enforced:

- hit effects: 32;
- muzzle effects: 12;
- death effects: 10, including elite cap 3;
- ground decals: 16.

This proves bounded active populations but also identifies a real transient
submission spike. It should be addressed through prewarming, request
coalescing/capping before construction, or spreading non-critical work across
frames. The result is retained as a baseline rather than hidden by a relaxed
threshold.

## Graphical Verification

With explicit user permission, Godot MCP ran the beacon/player layering
showcase using Vulkan Forward Mobile on an AMD Radeon RX 6700 XT. It generated a
capture showing the protocol cell complete while the player remained in the
foreground. No runtime crash occurred. Debug output contained existing
GDScript warnings, including integer-division warnings in VFX services and
several variable-shadowing warnings; these remain cleanup candidates rather
than Phase 4 functional failures.

## Verification

- Test selection infrastructure: PASS.
- Worker parser/process/isolation/scheduling infrastructure: PASS.
- Selected-runner infrastructure: PASS.
- Registered test catalog: 79 PASS, 0 FAIL, 0 ERROR.
- Registered catalog runtime errors: 0.
- Registered catalog shutdown diagnostics: 0.
- Startup resource manifest: PASS.
- Godot 4.7.1 headless check: PASS.
- Architecture budget violations: 0.
- `git diff --check`: PASS.

## Reproduction

```powershell
pwsh -NoProfile -File tools/run_phase4_baselines.ps1 `
  -Runs 10 `
  -GodotPath 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe'

pwsh -NoProfile -File tools/audit_architecture_budgets.ps1

pwsh -NoProfile -File tests/infrastructure/run_test_workers.ps1 `
  -GodotPath 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe'
```

Generated artifacts are retained under `test-results/phase4/`, including the
single-run baseline, VFX baseline, ten-run repeatability summary, raw isolated
runs and the full-regression summary.
