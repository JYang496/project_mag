## Goal
Fix the module purchase and upgrade economy so modules no longer appear as price `1` in the purchase menu. Implement balanced base prices for weapon modules and make module upgrade prices scale by current module level.

Codex should make the code and resource changes directly in the project. Do not change weapon prices in this task.

---

## Current behavior to fix

The module base class has an exported `cost` field:

```gdscript
@export var cost : int
```

The shop module slot scans `res://Player/Weapons/Modules/`, instantiates module scenes, sets previews to Lv.1, and calls:

```gdscript
GlobalVariables.economy_data.get_module_purchase_gold(int(module_instance.cost))
```

`EconomyConfig.get_module_purchase_gold()` currently clamps the minimum purchase price to `1`, so any module scene with missing or zero `cost` displays as price `1`.

Module upgrade logic also only passes `module_instance.cost`, not the current module level, so Lv.1 -> Lv.2 and Lv.2 -> Lv.3 use the same upgrade price.

---

## Required implementation summary

1. Set a non-zero `cost` on each module `.tscn` under:

```text
Player/Weapons/Modules/
```

2. Add level-aware module upgrade pricing to `data/EconomyConfig.gd`.

3. Update every module upgrade call site to pass the current `module_level`.

4. Reduce duplicate module conversion payout so the new higher module costs do not create excessive gold refunds.

5. Verify shop UI, module upgrade UI, and duplicate module conversion still work.

---

## Module base prices

Use the following prices as the authoritative base purchase cost. Codex should locate the matching module scenes by display name, `item_name`, root node name, file name, and/or effect text. Do not create new modules. If a listed module cannot be found, leave it unchanged and include it in the final implementation notes.

| Module display name | Base cost |
|---|---:|
| Recovery Magnet | 4 |
| Impact Coil | 5 |
| Reload Sprint | 5 |
| Projectile Speed / Faster Speed | 6 |
| Reload Link | 6 |
| Reload Shockwave | 6 |
| Dash Cooler | 6 |
| Size Up / Bullet Size | 7 |
| Diffusion Nozzle | 7 |
| Expanded Magazine | 7 |
| Crit Amplifier | 7 |
| Erosion / DoT On Hit | 7 |
| Heat Vent | 7 |
| Cryo Infuser | 7 |
| Chill Chain | 7 |
| Area Expander | 8 |
| Fast Reload | 8 |
| Reloaded Force | 8 |
| Reload Barrier | 8 |
| Crit Calibrator | 8 |
| Bleed Edge | 8 |
| Heat Capacity | 8 |
| Heat Throttle | 8 |
| Magazine Pressure | 9 |
| Kill Endurance | 9 |
| Reload Relay | 9 |
| Life Steal | 9 |
| Battle Focus | 9 |
| Brittle Trigger | 9 |
| Crossfire | 9 |
| Overkill Recovery | 9 |
| Molten Splash | 9 |
| Quick Cycle | 10 |
| Reload Burst | 10 |
| Inertial Aim | 10 |
| Firepower Diffusion | 10 |
| Penetration Momentum | 10 |
| Ice Prison | 10 |
| Momentum Haste | 11 |
| Plague Seed | 11 |
| Permafrost Field | 11 |
| Damage Up | 12 |
| Pierce | 12 |
| Corrosive Touch | 12 |
| Lightning Chain | 13 |
| Overheat Boost | 14 |
| Multi Launcher | 16 |
| Heat Concentration | 16 |

### How to edit module scene files

For each matched `.tscn`, add or update the exported `cost` property on the root node instance. Prefer placing it immediately after the `script = ExtResource(...)` line.

Example:

```gdscene
[node name="DamageUp" instance=ExtResource("1_2t80l")]
script = ExtResource("2_sw4r6")
cost = 12
level_effects = PackedStringArray("Weapon damage +50%", "Weapon damage +67.5%", "Weapon damage +85%")
```

If the file already has `cost = ...`, replace the existing value with the table value.

---

## Upgrade pricing rule

Recommended upgrade formula:

| Upgrade step | Price formula |
|---|---:|
| Lv.1 -> Lv.2 | `round(base_cost * 1.25)` |
| Lv.2 -> Lv.3 | `round(base_cost * 1.75)` |

This means the final prices for each module should be:

| Module display name | Buy | Lv.1 -> Lv.2 | Lv.2 -> Lv.3 |
|---|---:|---:|---:|
| Recovery Magnet | 4 | 5 | 7 |
| Impact Coil | 5 | 6 | 9 |
| Reload Sprint | 5 | 6 | 9 |
| Projectile Speed / Faster Speed | 6 | 8 | 11 |
| Reload Link | 6 | 8 | 11 |
| Reload Shockwave | 6 | 8 | 11 |
| Dash Cooler | 6 | 8 | 11 |
| Size Up / Bullet Size | 7 | 9 | 12 |
| Diffusion Nozzle | 7 | 9 | 12 |
| Expanded Magazine | 7 | 9 | 12 |
| Crit Amplifier | 7 | 9 | 12 |
| Erosion / DoT On Hit | 7 | 9 | 12 |
| Heat Vent | 7 | 9 | 12 |
| Cryo Infuser | 7 | 9 | 12 |
| Chill Chain | 7 | 9 | 12 |
| Area Expander | 8 | 10 | 14 |
| Fast Reload | 8 | 10 | 14 |
| Reloaded Force | 8 | 10 | 14 |
| Reload Barrier | 8 | 10 | 14 |
| Crit Calibrator | 8 | 10 | 14 |
| Bleed Edge | 8 | 10 | 14 |
| Heat Capacity | 8 | 10 | 14 |
| Heat Throttle | 8 | 10 | 14 |
| Magazine Pressure | 9 | 11 | 16 |
| Kill Endurance | 9 | 11 | 16 |
| Reload Relay | 9 | 11 | 16 |
| Life Steal | 9 | 11 | 16 |
| Battle Focus | 9 | 11 | 16 |
| Brittle Trigger | 9 | 11 | 16 |
| Crossfire | 9 | 11 | 16 |
| Overkill Recovery | 9 | 11 | 16 |
| Molten Splash | 9 | 11 | 16 |
| Quick Cycle | 10 | 13 | 18 |
| Reload Burst | 10 | 13 | 18 |
| Inertial Aim | 10 | 13 | 18 |
| Firepower Diffusion | 10 | 13 | 18 |
| Penetration Momentum | 10 | 13 | 18 |
| Ice Prison | 10 | 13 | 18 |
| Momentum Haste | 11 | 14 | 19 |
| Plague Seed | 11 | 14 | 19 |
| Permafrost Field | 11 | 14 | 19 |
| Damage Up | 12 | 15 | 21 |
| Pierce | 12 | 15 | 21 |
| Corrosive Touch | 12 | 15 | 21 |
| Lightning Chain | 13 | 16 | 23 |
| Overheat Boost | 14 | 18 | 25 |
| Multi Launcher | 16 | 20 | 28 |
| Heat Concentration | 16 | 20 | 28 |

---

## Code changes

### 1. Update `data/EconomyConfig.gd`

Keep the existing public function names so existing callers do not break. Add explicit level ratios and change `get_module_upgrade_gold()` to accept current level.

Recommended implementation:

```gdscript
@export_range(0.0, 10.0, 0.01) var module_upgrade_price_ratio: float = 1.0 # legacy fallback; keep for existing serialized resources
@export_range(0.0, 10.0, 0.01) var module_upgrade_level_2_ratio: float = 1.25
@export_range(0.0, 10.0, 0.01) var module_upgrade_level_3_ratio: float = 1.75
```

Replace the existing duplicate module multiplier default:

```gdscript
@export var duplicate_module_gold_cost_multiplier: float = 2.0
```

Replace the existing module upgrade function with:

```gdscript
func get_module_upgrade_gold(module_cost: int, current_level: int = 1) -> int:
	var purchase_value := float(get_module_purchase_gold(module_cost))
	var safe_level := clampi(current_level, 1, 2)
	var ratio := module_upgrade_level_2_ratio
	if safe_level >= 2:
		ratio = module_upgrade_level_3_ratio
	var upgrade_value := int(round(purchase_value * maxf(ratio, 0.0)))
	return maxi(upgrade_value, 1)
```

Rationale: `Module.MAX_LEVEL` is 3. The only paid upgrade steps are from current level 1 to 2, and current level 2 to 3.

### 2. Update `autoload/InventoryData.gd`

Find `upgrade_module_with_gold()` and replace:

```gdscript
var price := _get_economy_config().get_module_upgrade_gold(int(module_instance.cost))
```

with:

```gdscript
var price := _get_economy_config().get_module_upgrade_gold(
	int(module_instance.cost),
	int(module_instance.module_level)
)
```

### 3. Update `UI/scripts/management/module_upgrade_view.gd`

Find `get_upgrade_price(module_instance: Module)` and replace both calls that pass only `module_instance.cost`.

Recommended:

```gdscript
func get_upgrade_price(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		)
	return EconomyConfig.new().get_module_upgrade_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)
```

### 4. Update `UI/scripts/management/upgrade_management_view.gd`

Find `_get_module_upgrade_price(module_instance: Module)` and replace both calls that pass only `module_instance.cost`.

Recommended:

```gdscript
func _get_module_upgrade_price(module_instance: Module) -> int:
	if module_instance == null or not is_instance_valid(module_instance):
		return 0
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_module_upgrade_gold(
			int(module_instance.cost),
			int(module_instance.module_level)
		)
	return EconomyConfig.new().get_module_upgrade_gold(
		int(module_instance.cost),
		int(module_instance.module_level)
	)
```

### 5. Search for any remaining old call sites

Run a project-wide search for:

```text
get_module_upgrade_gold(
```

Every module upgrade context should now pass two arguments: `module_cost` and current `module_level`.

It is acceptable for unrelated tests or compatibility code to call with one argument because the function has a default `current_level = 1`, but active module upgrade UI/gameplay paths should pass both.

---

## Duplicate module conversion payout

Current duplicate conversion uses:

```gdscript
get_duplicate_module_gold(module_cost, module_level)
```

and `EconomyConfig` currently has:

```gdscript
duplicate_module_gold_cost_multiplier = 6.0
duplicate_module_gold_refund_ratio = 0.5
```

This effectively produces about `module_cost * 3 * module_level`, which is too high after module base costs are raised. Change only the multiplier default to:

```gdscript
duplicate_module_gold_cost_multiplier = 2.0
```

That makes conversion about `module_cost * 1.0 * module_level` before the configured minimum. This is still generous but no longer breaks the economy.

Do not remove `duplicate_module_gold_refund_ratio`.

---

## Balancing notes for review

The module price bands are intentional:

- `4-6`: utility, movement, minor control, or quality-of-life modules.
- `7-9`: moderate DPS, reload, crit, DoT, or conditional survivability modules.
- `10-12`: high-impact build modules and consistent DPS/synergy modules.
- `13-16`: build-defining or multiplicative scaling modules such as Lightning Chain, Multi Launcher, Heat Concentration, and Overheat Boost.

Weapon prices are already much higher, generally around `40`, `60`, and `80`, so module costs should stay below weapon costs but high enough to force a choice between buying a new weapon, upgrading a weapon, buying modules, and upgrading modules.

---

## Acceptance criteria

After implementation:

1. The module shop no longer shows all module prices as `1`.
2. A module with base cost `12` shows purchase price `12` with the default `module_purchase_price_multiplier = 1.0`.
3. A Lv.1 module with base cost `12` shows upgrade cost `15`.
4. The same module at Lv.2 shows upgrade cost `21`.
5. A module at Lv.3 is not upgradeable and shows as max level / no upgrade action.
6. Duplicates still merge into the existing module until Lv.3.
7. Duplicates beyond Lv.3 convert into gold without producing excessive refunds.
8. Weapon purchase and weapon upgrade prices remain unchanged.
9. No new module scene is introduced.
10. The project loads in Godot without parse errors from modified `.gd` or `.tscn` files.

---

## Manual smoke test

Use this checklist in a local Godot run:

1. Start a run with enough gold.
2. Open the purchase menu.
3. Confirm module cards show varied prices according to the base-cost table.
4. Buy at least one low-cost module, one mid-cost module, and one high-cost module.
5. Open the module upgrade UI.
6. Confirm Lv.1 -> Lv.2 price uses `round(base_cost * 1.25)`.
7. Upgrade one module to Lv.2.
8. Confirm Lv.2 -> Lv.3 price uses `round(base_cost * 1.75)`.
9. Upgrade to Lv.3.
10. Confirm the module disappears from upgradeable options or is disabled as max level.
11. Obtain a duplicate of a Lv.3 module and confirm it converts to gold using the reduced duplicate conversion amount.

---

## Final implementation note requested from Codex

After applying the patch, report:

- Which files were modified.
- Which module `.tscn` files received `cost` values.
- Any module names from the price table that could not be matched.
- The final `get_module_upgrade_gold()` signature.
- Whether all active upgrade call sites pass `module_level`.
