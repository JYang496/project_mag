extends Module
# Use on HEAT weapons to scale damage up as current heat ratio increases.

var ITEM_NAME := "Heat Concentration"

@export var alignment_damage_bonus_at_full: float = 0.15

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

	var alignment := 0.0
	if weapon.has_weapon_trait(WeaponTrait.FIRE):
		alignment = float(weapon.call("get_fire_alignment"))
	elif weapon.has_weapon_trait(WeaponTrait.FREEZE):
		alignment = float(weapon.call("get_freeze_alignment"))
	var scaled_bonus: float = get_effective_additive(maxf(alignment_damage_bonus_at_full, 0.0), 0.35) * clampf(alignment, 0.0, 1.0)
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
