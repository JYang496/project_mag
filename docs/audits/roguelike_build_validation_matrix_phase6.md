# Roguelike Build Validation Matrix - Phase 6

Date: 2026-06-30

## Purpose

Phase 6 establishes a repeatable build-validation contract before doing broad numeric tuning. The first pass is a smoke/contract layer, not a final balance report: it verifies that the matrix names real weapons, real branch ids, real module scenes, and a complete set of encounter pressure types.

## Files Read

- `docs/prompt/roguelike_gameplay_optimization_sequence.md`
- `tests/README.md`
- `tests/benchmarks/dps/real_combat_dps_benchmark.gd`
- `tests/benchmarks/dps/base_weapon_composite_dps_benchmark.gd`
- `tests/benchmarks/dps/weapon_branch_dps_benchmark.gd`
- `tests/headless/weapon/run_close_quarters_chain_test_headless.gd`
- `tests/headless/spawn/run_spawn_combat_profile_validation_headless.gd`
- `tests/headless/weapon/run_weapon_delivery_type_test_headless.gd`
- `data/test/dps_benchmark_config.gd`
- `data/test/dps_benchmark_default.tres`
- `tools/validate_weapon_branches.gd`
- `autoload/DataHandler.gd`
- `autoload/DamageManager.gd`
- `Combat/damage/damage_pipeline.gd`
- `Combat/damage/damage_result.gd`
- `Player/Weapons/close_quarters_chain_rules.gd`
- `Player/Weapons/Modules/*.tscn`
- `data/weapons/*.tres`
- `data/weapon_branches/*.tres`

## Files Added

- `data/test/build_validation_matrix.gd`
- `data/test/build_validation_matrix_default.tres`
- `tests/headless/combat/run_build_validation_matrix_test_headless.gd`
- `tests/headless/combat/run_build_validation_matrix_report_test_headless.gd`
- `tools/generate_build_validation_matrix_report.gd`
- `tools/generate_build_balance_regression_report.gd`
- `docs/reports/build_validation_matrix.html`
- `docs/reports/build_balance_regression_smoke_report.html`
- `docs/audits/roguelike_build_validation_matrix_phase6.md`

## Matrix Contract

The matrix currently covers six build groups:

| Build | Weapons | Strengths | Weaknesses |
| --- | --- | --- | --- |
| Heat Loop | Machine Gun, Flamethrower, Plasma Lance, Orbit | Swarm, task objective combat | high-HP elite, ranged siege |
| Mark Execute | Auto Pistol, Spear Launcher, Sniper, Cannon | high-HP elite, support core | swarm, close pressure, task objective combat |
| Freeze Control | Glacier Projector, Shotgun, Dash Blade, Orbit | ranged siege, close pressure, support core | high-HP elite |
| Close Risk | Dash Blade, Chainsaw Launcher, Shotgun, Flamethrower | close pressure, swarm | ranged siege, support core |
| Area Control | Rocket Launcher, Laser, Flamethrower, Orbit | swarm, support core, task objective combat | high-HP elite, close pressure |
| Reload Rhythm | Cannon, Rocket Launcher, Sniper, Machine Gun | high-HP elite, ranged siege | swarm, close pressure |

It covers six encounter pressure types:

- 60s Swarm Clear
- Single High-HP Elite
- Support Enemy + Shield Core
- Ranged Siege
- Close Pressure
- Task Objective Combat

## Design Decisions

- The first Phase 6 implementation is a contract test, not a numeric balance gate. This follows the phase requirement that smoke/contract tests may come before value reports.
- The matrix uses current `weapon_id`, branch ids, and module scene paths so later benchmark scenes can consume the same data without duplicating build definitions.
- No weapon, route, reward, or enemy values were changed. This avoids masking regressions from earlier phases with new balance changes.
- The test explicitly rejects an omnibuild by requiring each build to have weaknesses and by requiring every encounter to appear as both a strength and a weakness across the matrix.

## Not Done Yet

- No 60-second runtime combat simulation was added yet.
- No numeric DPS or survival threshold is attached to the matrix yet.
- No route/reward timing analysis is automated yet.

These are deliberately left for the next pass because the current repo already has single-weapon and branch DPS benchmarks, while the missing foundation was a shared build-case contract for multi-weapon validation. The added HTML report is a matrix/reporting artifact, not a measured combat result.

## Report Artifact

- Output: `docs/reports/build_validation_matrix.html`
- Generator: `tools/generate_build_validation_matrix_report.gd`
- Source data: `data/test/build_validation_matrix_default.tres`

The report renders the build x encounter matrix, resolves current weapon names, resolves branch names, resolves module display names, and keeps an explicit note that it is not yet a measured DPS or survival report.

## Balance Regression Smoke Report

- Output: `docs/reports/build_balance_regression_smoke_report.html`
- Generator: `tools/generate_build_balance_regression_report.gd`
- Source data: `data/test/build_validation_matrix_default.tres`

The smoke report summarizes each build's strong/neutral/weak matchup counts, checks for declared omnibuild risk, checks encounter strength/weakness coverage, and records that route timing, reward-pool timing, DPS, survival, and objective completion values remain unmeasured.

## Validation

- `git diff --check`
  - Result: exit code 0.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/combat/run_build_validation_matrix_test_headless.gd`
  - Result: exit code 0.
  - Coverage: verifies build ids, encounter coverage, weapon ids, branch ids, module paths, strength/weakness refs, and the no-omnibuild contract.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tools/generate_build_validation_matrix_report.gd`
  - Result: exit code 0.
  - Output: `docs/reports/build_validation_matrix.html`.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tools/generate_build_balance_regression_report.gd`
  - Result: exit code 0.
  - Output: `docs/reports/build_balance_regression_smoke_report.html`.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/combat/run_build_validation_matrix_report_test_headless.gd`
  - Result: exit code 0.
  - Coverage: verifies both generated reports exist and contain every build and encounter label from the matrix.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit`
  - Result: exit code 0.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/weapon/run_close_quarters_chain_test_headless.gd`
  - Result: exit code 0.
  - Note: Godot still logged an exit-cleanup warning about leaked ObjectDB/resource state in this existing test.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/spawn/run_spawn_combat_profile_validation_headless.gd`
  - Result: exit code 0.
- `& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tools/validate_weapon_branches.gd`
  - Result: exit code 0.

## Residual Risk

- Godot `--script` runs in this checkout sometimes return exit code 0 without printing the expected PASS line in stdout, so this report records process status and any emitted errors/warnings.
- The matrix proves current references and coverage, but it does not yet prove numeric balance. The next Phase 6 pass should add a scene or benchmark that consumes `build_validation_matrix_default.tres` and records per-build results for the six encounter types.
