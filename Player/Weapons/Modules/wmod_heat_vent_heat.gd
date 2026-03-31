extends Module
# Use on HEAT weapons to boost cooling, with stronger effect at higher heat.

var ITEM_NAME := "Heat Vent"

@export var cool_rate_mult: float = 1.5

func configure_stat_modifiers() -> void:
	stat_multipliers["heat_cool_rate"] = cool_rate_mult

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	var output := super.apply_stat_modifiers(stat_block)
	if output == null or output.is_empty() or not output.has("heat_cool_rate"):
		return output
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not _is_valid_heat_weapon(weapon):
		return output

	var base_cool_rate := float(stat_block.get("heat_cool_rate", output["heat_cool_rate"]))
	var final_mult := get_effective_multiplier(maxf(cool_rate_mult, 1.0))
	var heat_ratio: float = clampf(float(weapon.call("get_heat_ratio")), 0.0, 1.0)
	var dynamic_mult := lerpf(1.0, final_mult, heat_ratio)
	output["heat_cool_rate"] = base_cool_rate * dynamic_mult
	return output

func _is_valid_heat_weapon(target_weapon: Weapon) -> bool:
	if target_weapon == null:
		return false
	if not target_weapon.has_method("has_heat_trait"):
		return false
	if not bool(target_weapon.call("has_heat_trait")):
		return false
	return target_weapon.has_method("get_heat_ratio")
