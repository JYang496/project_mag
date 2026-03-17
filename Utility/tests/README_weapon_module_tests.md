# Weapon Module Test Plan Runner

This folder includes a runnable in-project test harness for the weapon module and fuse integrity fixes.

## Files

- `res://Utility/tests/weapon_module_test_runner.tscn`
- `res://Utility/tests/weapon_module_test_runner.gd`
- `res://Utility/tests/mocks/test_weapon.tscn`
- `res://Utility/tests/mocks/test_weapon.gd`
- `res://Utility/tests/mocks/test_enemy.gd`

## How To Run

1. Open the project in Godot.
2. Open scene: `res://Utility/tests/weapon_module_test_runner.tscn`.
3. Press Play Scene (`F6`).
4. Read the Output panel for `[PASS]` / `[FAIL]` lines and final summary.

## Manual Feature Scene

For interactive validation of module obtain/upgrade/convert messaging:

1. Open scene: `res://Utility/tests/module_feature_manual_test.tscn`.
2. Press Play Scene (`F6`).
3. Use keys:
- `1`: Obtain `Damage Up`
- `2`: Obtain `Pierce`
- `3`: Force `Damage Up` to max then apply duplicate (coin conversion path)
- `R`: Reset runtime state

## Coverage Mapping To Test Plan

1. Module activation smoke test:
- Installs `DamageUp`, `FasterReload`, `MoreHP`, and `Pierce`.
- Verifies stat deltas apply.
- Duplicates/re-enters weapon and verifies deltas still apply.

2. Module unique/upgrade/convert test:
- Obtaining first module adds Lv.1 module.
- Obtaining duplicate upgrades existing module level.
- Obtaining duplicate at max level converts into gold.

3. Compatibility guard test:
- Verifies `Pierce` install is blocked on melee-only weapon.
- Verifies `Pierce` installs on ranged weapon.

4. Fuse integrity test:
- Fuses two same-name weapons:
  - Base weapon has 2 modules.
  - Consumed non-base weapon has 1 module.
- Verifies fused weapon keeps base modules.
- Verifies only non-base module is salvaged into module inventory.

5. Runtime stability + cleanup:
- Equips on-hit modules (`stun`, `slow`, `life_steal`, `lightning_chain`).
- Verifies effects trigger on hit.
- Verifies `_on_tree_exited` cleanup clears plugin/runtime branch refs.
