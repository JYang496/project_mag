extends Module
# Use on HEAT weapons to scale damage up as current heat ratio increases.

var ITEM_NAME := "Heat Concentration"

@export var heat_damage_bonus_at_full_heat: float = 1.4

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	var output := super.apply_stat_modifiers(stat_block)
	if output == null or output.is_empty() or not output.has("damage"):
		return output
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null:
		return output
	if not _is_valid_heat_weapon(weapon):
		return output

	var heat_ratio: float = clampf(float(weapon.call("get_heat_ratio")), 0.0, 1.0)
	var scaled_bonus: float = get_effective_additive(maxf(heat_damage_bonus_at_full_heat, 0.0), 0.35) * heat_ratio
	output["damage"] = float(output["damage"]) * (1.0 + scaled_bonus)
	return output

func _is_valid_heat_weapon(target_weapon: Weapon) -> bool:
	if target_weapon == null:
		return false
	if not target_weapon.has_method("has_heat_trait"):
		return false
	if not bool(target_weapon.call("has_heat_trait")):
		return false
	return target_weapon.has_method("get_heat_ratio")
