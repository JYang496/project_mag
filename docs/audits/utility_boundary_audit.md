# Utility Boundary Audit

Date: 2026-06-27

Scope: Utility boundary cleanup was executed for the non-combat owners and the shared combat-core primitives. `Utility/` has no remaining files.

## Current Inventory

`Utility/` no longer owns world spawn, battle reward, save-data, weapon smoke-test, or shared combat-core files. The remaining folder has been removed after verifying it contained no files.

| Area | Files | Current role |
| --- | --- | --- |
| Combat primitives | `Combat/attack/Attack.gd`, `Combat/damage/**`, `Combat/collision/**`, `Combat/status/**`, `Combat/area_effect/**` | Shared damage, collision, status, and area-effect primitives used by Player, Npc, tests, and resources. |

Moved ownership:

| Area | New files | Current role |
| --- | --- | --- |
| World spawn/runtime | `World/spawn/enemy_spawner.tscn`, `World/spawn/enemy_spawner.gd`, `World/spawn/spawn_point_picker.gd`, `World/spawn/spawn_budget_runtime.gd`, `World/spawn/kill_gold_budget_runtime.gd` | Battle spawn orchestration and spawn/economy budget helpers. |
| Reward/drop runtime | `World/rewards/reward_manager.tscn`, `World/rewards/reward_manager.gd`, `World/rewards/reward_info.gd`, `World/rewards/module_reward_option.gd` | Battle reward selection, drop spawning, and reward option resources. |
| Save data | `data/savedata/savedata.gd` | Save-game resource used by `data/savedata/autosave.tres`. |
| Test harness | `tests/scenes/weapon/test_weapon_smoke.tscn`, `tests/headless/weapon/run_test_weapon_smoke_headless.gd` | Weapon smoke-test entrypoint under the test tree. |

`DisplaySettings` has already moved out of `Utility/` to `autoload/DisplaySettings.gd`.

## Reference Evidence

Repo-wide search pattern:

```powershell
rg -n 'res://Utility/|preload\("res://Utility|load\("res://Utility|Utility/' -S .
```

Key current references:

- `World/world.tscn` instantiates `res://World/spawn/enemy_spawner.tscn` and `res://World/rewards/reward_manager.tscn`.
- `World/spawn/enemy_spawner.gd` preloads `spawn_point_picker.gd`, `spawn_budget_runtime.gd`, and `kill_gold_budget_runtime.gd` from `res://World/spawn/`.
- `data/savedata/autosave.tres` points at `res://data/savedata/savedata.gd`.
- Player projectiles, weapon instances, weapon effects, Npc scenes, and test runners now reference `Combat/collision/**` and `Combat/area_effect/**`.
- `tests/headless/reward/run_loot_rarity_reward_test_headless.gd`, `tests/probes/economy/run_kill_gold_drop_probe_headless.gd`, and `tests/probes/world/infinite_mode_smoke_test.gd` directly load the moved World scenes for focused verification.
- `project.godot` still has only a folder color entry for `res://Utility/`; this is cosmetic, not runtime ownership.

## Ownership Classification

| Item | Classification | Rationale |
| --- | --- | --- |
| `World/spawn/enemy_spawner.*` | Moved from `Utility/` | It depends on world board markers, spawn data, phase state, and battle economy. `World/world.tscn` is the primary live owner. |
| `World/spawn/spawn_point_picker.gd` | Moved with spawner | It is a spawn-domain helper preloaded only by `enemy_spawner.gd`. |
| `World/spawn/spawn_budget_runtime.gd` | Moved with spawner | Spawn budget logic is battle-spawn specific and currently internal to `enemy_spawner.gd`. |
| `World/spawn/kill_gold_budget_runtime.gd` | Moved with spawner | It is kill-gold budget logic owned by battle spawn/economy flow. Keeping it with spawner minimizes reference churn. |
| `World/rewards/reward_manager.*` | Moved from `Utility/` | `World/world.tscn` owns it and it coordinates battle reward/drop generation rather than a generic utility. |
| `World/rewards/reward_info.gd`, `World/rewards/module_reward_option.gd` | Moved with reward manager | These are reward data structures. They remain with reward runtime until a broader resource/data pass is scheduled. |
| `data/savedata/savedata.gd` | Moved from `Utility/` | It is a Resource type consumed from `data/savedata/autosave.tres`. |
| `Combat/damage/**` | Moved from `Utility/damage/**` | Cross-domain combat contract with class names such as `DamagePipeline`, `DamageData`, `DamageProfile`, and `DamageResult`. |
| `Combat/collision/**` | Moved from `Utility/hit_hurt_box/**` | Used by Player, Npc, projectiles, and tests; scene ext_resource paths now point at `res://Combat/collision/`. |
| `Combat/status/**` | Moved from `Utility/status_effects/**` | Shared combat status model used with damage and hit/hurt contracts. |
| `Combat/area_effect/**` | Moved from `Utility/area_effect/**` | Shared combat VFX/damage infrastructure used by weapon branches/effects and Npc enemy attacks. |
| `Combat/attack/Attack.gd` | Moved from `Utility/classes/Attack.gd` | Legacy generic combat payload, retained with the combat-core package. |
| `tests/scenes/weapon/test_weapon_smoke.tscn`, `tests/headless/weapon/run_test_weapon_smoke_headless.gd` | Moved from `Utility/` | It is test-only content and now follows the current test-tree convention. |

## Completed Cleanup

1. **World spawn slice**
   - Moved `enemy_spawner.tscn`, `enemy_spawner.gd`, `spawn_point_picker.gd`, `spawn_budget_runtime.gd`, and `kill_gold_budget_runtime.gd` to `World/spawn/`.
   - Updated `World/world.tscn`, the spawner scene ext_resource, and focused tests that load the spawner.

2. **World reward slice**
   - Moved `reward_manager.tscn`, `reward_manager.gd`, `reward_info.gd`, and `module_reward_option.gd` to `World/rewards/`.
   - Updated `World/world.tscn` and `tests/headless/reward/run_loot_rarity_reward_test_headless.gd`.

3. **Save data slice**
   - Moved `savedata.gd` to `data/savedata/savedata.gd`.
   - Updated `data/savedata/autosave.tres`.

4. **Test harness cleanup**
   - Moved `test_weapon_smoke.tscn` to `tests/scenes/weapon/test_weapon_smoke.tscn`.
   - Moved `test_weapon_smoke_node.gd` to `tests/headless/weapon/run_test_weapon_smoke_headless.gd`.

5. **Combat-core slice**
   - Moved `Attack.gd` to `Combat/attack/`.
   - Moved damage contracts to `Combat/damage/`.
   - Moved status contracts to `Combat/status/`.
   - Moved hit/hurt scripts and scenes to `Combat/collision/`.
   - Moved area-effect scripts and scenes to `Combat/area_effect/`.
   - Updated Player, Npc, Board/World/test runtime references that still pointed at `res://Utility/`.
   - Verified `rg --files Utility` returned no files, then removed the empty `Utility/` folder tree.

No intentionally retained `Utility/` files remain.

## Validation

Executed after the moves:

```powershell
rg -n "res://Utility/(enemy_spawner|spawn_point_picker|spawn_budget_runtime|kill_gold_budget_runtime|reward_manager|reward_info|module_reward_option|savedata|test_weapon_smoke|test_weapon_smoke_node)" . --glob '!docs/prompt/**' --glob '!docs/audits/**' --glob '!*.uid'
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/spawn/ranged_spawn_limits_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/probes/economy/kill_gold_drop_probe.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/probes/world/infinite_mode_smoke_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/reward/loot_rarity_reward_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/test_weapon_smoke.tscn
```

Results:

- Old non-combat `res://Utility/...` paths had no runtime-source matches outside archived docs/prompts.
- `--check-only` completed with no errors.
- `ranged_spawn_limits_test.tscn` printed `PASS: ranged spawn batch and alive limits`.
- `loot_rarity_reward_test.tscn` printed `LootRarityRewardTest: PASS`.
- `kill_gold_drop_probe.tscn`, `infinite_mode_smoke_test.tscn`, and `test_weapon_smoke.tscn` exited with code `0`; the weapon smoke scene still emits Godot resource cleanup warnings at exit.

Executed after the combat-core move:

```powershell
rg -n "res://Utility/(classes|damage|status_effects)" . --glob '!docs/prompt/**' --glob '!docs/audits/**' --glob '!*.uid'
rg -n "res://Utility/hit_hurt_box|Utility/hit_hurt_box" . --glob '!docs/prompt/**' --glob '!docs/audits/**' --glob '!*.uid'
rg -n "res://Utility/area_effect|Utility/area_effect" . --glob '!docs/prompt/**' --glob '!docs/audits/**' --glob '!*.uid'
rg -n "res://Utility/|Utility/" Player Npc World Board autoload data tests UI tools --glob '!*.uid'
rg --files Utility
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --check-only --quit
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/combat/run_hitbox_owner_test_headless.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/headless/combat/run_mark_status_effect_test_headless.gd
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/weapon_passive_charge_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/weapon_numeric_module_test.tscn
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --scene res://tests/scenes/weapon/heat_passive_test.tscn
```

Results:

- Old combat `res://Utility/...` paths had no runtime-source matches outside archived docs/prompts.
- `rg -n "res://Utility/|Utility/" Player Npc World Board autoload data tests UI tools --glob '!*.uid'` returned no matches.
- `rg --files Utility` returned no files before empty-folder removal; after removal it reports the `Utility` path is missing.
- `git diff --check -- Combat Utility Player Npc Board autoload tests World data docs/audits` exited with code `0`; it reported the existing CRLF normalization warning for `data/test/dps_benchmark_default.tres`.
- `--check-only`, `run_hitbox_owner_test_headless.gd`, `run_mark_status_effect_test_headless.gd`, `weapon_numeric_module_test.tscn`, and `heat_passive_test.tscn` exited with code `0`.
- `weapon_passive_charge_test.tscn` exited with code `0` but emitted a test error because `res://docs/weapon_passive_contract_matrix.md` is missing. No current path for `weapon_passive_contract_matrix.md` was found under `docs` or `tests`.
- `run_mark_status_effect_test_headless.gd` emitted Godot resource cleanup warnings at exit: `ObjectDB instances leaked` and `5 resources still in use at exit`.
- `weapon_numeric_module_test.tscn` emitted Godot resource cleanup warnings at exit: `ObjectDB instances leaked` and `4 resources still in use at exit`.
