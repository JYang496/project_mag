# Phase 4: Performance Baselines and Architecture Growth Controls

## Purpose

Phase 4 makes performance and maintainability measurable before Phase 3 adds
rule-changing protocols and cells. It does not begin by optimizing arbitrary
code. It first establishes deterministic workloads, identifies proven hot
paths, and prevents already-large owners from absorbing new responsibilities.

## Current Baseline

Approximate large-script sizes observed before Phase 4 planning:

| Owner | Approximate lines before current work | Primary risk |
|---|---:|---|
| `Player/Mechas/scripts/Player.gd` | 1881 | input, movement, combat and presentation coupling |
| `UI/scripts/UI.gd` | 1676 | phase, HUD, modal and management coordination |
| `World/spawn/enemy_spawner.gd` | 1313 | planning, budget, spawn execution and cleanup |
| `UI/scripts/reward_selection_panel.gd` | 1310 | parsing, presentation, input and reward submission |
| `UI/scripts/weapon_selector.gd` | 1285 | runtime state and presentation coupling |
| `World/board_cell_generator.gd` | 1133 | generation, cell rules and lifecycle coordination |
| `Player/Weapons/Core/weapon.gd` | 917 | weapon state, effects and orchestration |

Phase 2 has already moved reward-card data assembly out of the selection panel,
reducing that owner by more than 300 lines. Phase 4 applies the same
responsibility-first method to the remaining owners.

## Outcomes

Phase 4 is complete when:

1. Four deterministic workload classes run headlessly and write comparable
   machine-readable results.
2. Results cover representative 80, 160, and 240 enemy scales where applicable.
3. Average, p95, p99, and maximum frame time are reported together with the
   counters needed to explain them.
4. A repeated second-battle workload proves that runtime cost and live-object
   counts do not drift materially.
5. Large-file growth rules are documented and enforced by a lightweight audit.
6. At least two large owners have one proven responsibility migrated behind a
   narrow interface without changing combat semantics.
7. Performance claims compare identical seeds, compositions, density, phases,
   and sample windows.

## Workstream A: Benchmark Harness

### A1. Define a result schema

Add a versioned result object containing:

```text
schema_version
revision
scenario_id
seed
enemy_count
enemy_composition
density_profile
protocol_id
active_cell_rules
warmup_frames
sample_frames
average_frame_ms
p95_frame_ms
p99_frame_ms
maximum_frame_ms
spawned_nodes
freed_nodes
registry_queries
scanned_candidates
collision_contacts
vfx_spawned
pool_hits
pool_misses
shutdown_diagnostics
```

The harness must retain raw frame samples or a histogram sufficient to verify
percentile calculations. Missing counters should be `null` or explicitly
unsupported, not silently reported as zero.

### A2. Deterministic scenario contract

Every scenario must explicitly set:

- random seed;
- arena and cell layout;
- enemy composition and spawn positions;
- weapon/loadout configuration;
- protocol and cell modifiers;
- warm-up duration;
- measurement duration;
- cleanup boundary.

No benchmark may use the player's local save or ambient `user://` data.

### A3. Four workload classes

#### Spawn burst

Measure resource preparation, instantiation, `_ready`, registry insertion, and
collision activation. Record nodes created per frame and maximum spawn-frame
time.

#### Dense steady combat

Maintain a fixed population and density long enough to separate steady work
from spawn cost. Record registry queries, scanned candidates, collision work,
AI refreshes, and frame percentiles.

#### Bulk death and effects

Kill a fixed number of enemies on the same frame or controlled frame batches.
Record death callbacks, VFX, drops, pool behavior, freed nodes, and longest
frame. Run variants with presentation enabled and reduced to distinguish
gameplay and VFX cost.

#### Battle teardown and repeat

Run a full battle, settlement cleanup, and the same second battle in one test.
Compare percentiles, active signals, live nodes, registry size, pools, timers,
and transient groups between runs.

### A4. Representative scales

Use these as starting workloads, subject to target-hardware calibration:

| Scale | Purpose | Initial soft target |
|---:|---|---|
| 80 enemies | normal combat | p99 <= 16.7 ms |
| 160 enemies | high pressure | p99 <= 25 ms |
| 240 enemies | extreme diagnostic | p99 <= 40 ms without sustained drift |
| 80 simultaneous deaths | transient stress | max frame <= 50 ms |

These begin as reporting thresholds. They become hard CI failures only after at
least ten stable baseline runs on the same worker class establish normal
variance.

## Workstream B: Instrumentation

### B1. Counters at existing ownership boundaries

Instrument narrow APIs instead of scattering profiling calls across entities:

- `EnemyRegistry`: query count, candidate count, fallback full scans;
- enemy spawner: requested, created and activated enemies per frame;
- object pool: hit, miss, return and discarded instance counts;
- combat VFX services: requested, emitted, capped and pooled effects;
- battle cleanup coordinator: nodes/signals/timers removed per frame;
- physics-facing helpers: query and contact counts when available.

Counters reset at scenario start and return immutable snapshots. Production
builds may disable detailed counters, but the call sites must preserve behavior.

### B2. Frame sample collection

Collect elapsed frame time after warm-up. Report:

- mean for throughput;
- p95 and p99 for repeated hitches;
- maximum for transient spikes;
- the phase and counters associated with the longest frame.

Do not claim improvement from average FPS alone.

## Workstream C: Diagnose Before Optimizing

For each failed or suspicious scenario:

1. Identify whether the cost occurs during spawn, steady combat, dense contact,
   periodic refresh, bulk death, cleanup, or second-battle reuse.
2. Separate CPU/script, physics, rendering, allocation and I/O evidence.
3. Estimate worst-case complexity.
4. Add a counter or a smaller reproduction if evidence cannot distinguish
   candidates.
5. Change the authoritative owner, not a downstream visual symptom.
6. Compare the identical workload before and after.
7. Preserve first-frame targeting, special blockers, collision restoration,
   target invalidation and cleanup semantics with regression tests.

Preferred optimization order:

1. cache stable targets and results;
2. merge duplicate same-frame queries;
3. stagger synchronized refreshes;
4. cap approximate crowd work with fair rotation;
5. spread spawn, VFX and cleanup bursts across frames;
6. add or improve spatial indexing behind existing query APIs;
7. simplify dense physics interactions where gameplay permits;
8. reduce population only as an explicit design tradeoff.

## Workstream D: Architecture Growth Controls

### D1. Large-file policy

Apply the following initially as a report:

- Files over 800 nonblank code lines are growth-controlled owners.
- Adding more than 30 net code lines to a controlled owner requires either:
  - migrating one named responsibility out of that owner; or
  - a documented exception explaining why a new component would worsen
    ownership or lifecycle safety.
- A new function over 80 lines is reported for review.
- UI owners may not implement combat-rule decisions.
- Resource definitions may not depend on concrete UI nodes.
- New protocol behavior must use a typed rule context rather than add more
  global tree searches.

Upgrade these from reporting to merge gates after two development cycles show
that the audit produces few false positives.

### D2. Lightweight audit command

Add a deterministic script that reports:

- nonblank code lines for runtime `.gd` files;
- delta against a checked-in budget file;
- newly over-budget owners;
- functions above the review threshold;
- an explicit allowlist with owner, reason and expiry/review date.

The budget is a ratchet: existing large files may retain their current ceiling,
but the ceiling should decrease after responsibilities are moved out. It may not
silently increase to make CI green.

### D3. Initial extraction order

1. `enemy_spawner.gd`: extract spawn-plan generation and benchmark counters.
2. `board_cell_generator.gd`: extract Phase 3 rule installation and teardown.
3. `UI.gd`: extract protocol/cell HUD coordination.
4. `weapon.gd`: expose an immutable build-tag snapshot provider.
5. `Player.gd`: move one self-contained system only when a feature touches it;
   avoid a broad rewrite.
6. `weapon_selector.gd`: separate display models from inventory mutations.

Each extraction requires focused behavior tests before moving code, then the
same tests after the move. Line-count reduction alone is not proof of improved
ownership.

## Workstream E: Automation and Rollout

### E1. Local/PR tiers

| Tier | Runs | Purpose |
|---|---|---|
| Per change | compile, startup manifest, focused semantic tests | fast correctness |
| Pull request | 80 and selected 160 workloads, architecture audit | regression signal |
| Nightly/manual | all 80/160/240 variants and second-battle repeat | trend and extremes |
| Release candidate | target-hardware matrix and graphical verification | ship decision |

Performance result artifacts must be retained even when the run passes.

### E2. Noise control

- Use isolated user-data roots through the existing Worker infrastructure.
- Do not run unrelated heavy scenarios concurrently on the same worker.
- Record worker/CPU identity when available.
- Use multiple samples and compare medians before changing a threshold.
- Classify an isolated outlier as inconclusive until reproduced.

### E3. CI promotion rules

A metric becomes a hard gate when:

1. the scenario has a deterministic seed and fixed workload;
2. ten or more baseline runs establish variance;
3. the threshold includes a documented tolerance;
4. a failure prints an exact local reproduction command;
5. semantic regressions remain separate from performance regressions.

## Detailed Execution Sequence

1. Record current revision, dirty paths and existing large-file budgets.
2. Define and test percentile/result serialization as pure logic.
3. Add a minimal deterministic scene with no combat to validate harness timing,
   teardown and JSON output.
4. Add EnemyRegistry, spawner and ObjectPool counters behind reset/snapshot APIs.
5. Implement the 80-enemy spawn and steady-state scenarios.
6. Validate repeatability over ten local runs; fix scenario noise before adding
   thresholds.
7. Add 160 and 240 scale parameters without copying scenario code.
8. Implement bulk-death variants with VFX enabled and reduced.
9. Implement battle teardown plus identical second-battle replay.
10. Capture the first complete baseline and retain its artifacts.
11. Add the architecture budget file and reporting-only audit.
12. Extract spawn-plan generation from `enemy_spawner.gd`; prove identical seeded
    plans before and after.
13. Extract Phase 3 cell-rule coordination from `board_cell_generator.gd` before
    implementing its first vertical slice.
14. Run two development cycles with performance and architecture reports.
15. Calibrate thresholds from observed variance and target hardware.
16. Promote stable 80/160 scenarios and architecture ratchets to PR gates.
17. Keep 240-scale, full VFX and release hardware matrices in nightly/release
    tiers unless their runtime becomes small enough for every PR.

## Verification Checklist

- Godot 4.7.1 headless compilation passes.
- Startup resource manifest passes.
- Benchmark parser/percentile tests pass.
- Every scenario prints an explicit PASS/FAIL and exits through shared teardown.
- Successful Workers report zero runtime errors and expected shutdown
  diagnostics.
- Same scenario and seed produce the same entity composition and state changes.
- Second battle has no material registry, node, signal, timer or performance
  drift.
- Architecture budget cannot be silently raised by the audit tool.
- `git diff --check` passes and unrelated dirty work remains untouched.

## Non-Goals

- Rewriting all large owners at once.
- Lowering enemy caps before measuring the active bottleneck.
- Treating compilation as performance proof.
- Comparing different enemy compositions or presentation settings as evidence
  of optimization.
- Introducing a general-purpose framework that Phase 3 vertical slices do not
  actually consume.
