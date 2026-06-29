# Test Tree Migration Record

Date: 2026-06-27

Scope: completed migration of the legacy test folder into `res://tests/`.

## Current State

The legacy test folder has been removed from the working tree. All former test scenes, headless runners, fixtures, probes, showcases, and benchmarks now live under `tests/`.

Current entrypoint groups:

```text
tests/
  archive/benchmarks/
  benchmarks/dps/
  benchmarks/enemy_registry/
  benchmarks/weapon_formula/
  fixtures/enemies/
  fixtures/weapons/
  headless/cell/
  headless/combat/
  headless/enemy/
  headless/reward/
  headless/spawn/
  headless/ui/
  headless/weapon/
  headless/world/
  probes/economy/
  probes/enemy/
  probes/rest_area/
  probes/weapon/
  probes/world/
  scenes/cell/
  scenes/enemy/
  scenes/reward/
  scenes/spawn/
  scenes/ui/
  scenes/weapon/
  scenes/world/
  showcases/ui/
  showcases/weapon/
```

## Migration Rules Now In Force

- New automated regression scenes should go under `tests/scenes/<domain>/`.
- New scene-backed headless runners should go under `tests/headless/<domain>/`.
- Shared test-only resources should go under `tests/fixtures/<domain>/`.
- Measurement tools should go under `tests/benchmarks/<domain>/`.
- Probe and smoke checks should go under `tests/probes/<domain>/`.
- Manual or visual review scenes should go under `tests/showcases/<domain>/`.
- Old or superseded benchmark surfaces should stay under `tests/archive/` until explicitly deleted.

Do not add new files to the removed legacy location. Use the `tests/README.md` convention guide for new work.

## Validation Commands

Use the Steam Godot executable for shell validation:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Minimum validation after future test moves:

```powershell
rg -n "res://World/Test/|World/Test/" -S .
rg -n "res://tests/" -S tests docs project.godot
git diff --check
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
```

Representative scene/script validation examples:

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/probes/economy/kill_gold_drop_probe.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/weapon_numeric_module_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/benchmarks/dps/real_combat_dps_benchmark.tscn
```

## Follow-Up Cleanup

The migration preserved archive/probe/showcase content conservatively. A later pruning pass can review:

- `tests/archive/benchmarks/dps_benchmark.tscn`
- `tests/probes/enemy/enemy_spike_turret_behavior_probe.tscn`
- `tests/probes/world/infinite_mode_smoke_test.tscn`
- `tests/showcases/weapon/laser_branch_showcase.tscn`
- `tests/probes/weapon/machine_gun_spread_probe.tscn`
- `tests/showcases/ui/rarity_ui_showcase.tscn`
- `tests/probes/rest_area/rest_area_current_cell_probe.tscn`
- `tests/showcases/weapon/weapon_fuse_manual_test.tscn`

Only delete those after proving no unique coverage remains and after running Godot validation.
