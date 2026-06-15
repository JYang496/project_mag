extends Module

@export var item_name: String = "Weapon Stat"
@export var stat_key: String = ""
@export var multiplier_lv1: float = 1.0
@export var multiplier_lv2: float = 1.0
@export var multiplier_lv3: float = 1.0
@export var additive_lv1: float = 0.0
@export var additive_lv2: float = 0.0
@export var additive_lv3: float = 0.0
@export var required_property: String = ""
@export var requires_ammo_system: bool = false

func get_module_display_name() -> String:
	return item_name if item_name != "" else super.get_module_display_name()

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	var base_reason := super.get_incompatibility_reason(target_weapon)
	if base_reason != "":
		return base_reason
	if required_property != "" and target_weapon.get(required_property) == null:
		return "Requires weapon property: %s" % required_property
	if requires_ammo_system and not target_weapon.uses_ammo_system():
		return "Requires an ammo-based weapon."
	if stat_key == "projectile_count" and not target_weapon.supports_multi_launcher_module():
		return "Requires a weapon with shared multi-projectile firing."
	return ""

func configure_stat_modifiers() -> void:
	if stat_key == "":
		return
	stat_multipliers[stat_key] = _get_multiplier()
	var additive := _get_additive()
	if not is_zero_approx(additive):
		stat_additives[stat_key] = additive
	else:
		stat_additives.erase(stat_key)

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	if stat_block == null:
		return {}
	if stat_key == "" or not stat_block.has(stat_key):
		return stat_block.duplicate(true)
	var output := stat_block.duplicate(true)
	output[stat_key] = (float(output[stat_key]) + _get_additive()) * _get_multiplier()
	return output

func get_effect_descriptions() -> PackedStringArray:
	return with_level_effect_descriptions(PackedStringArray())

func _get_multiplier() -> float:
	return WeaponModuleRuntimeUtils.get_value_by_level(
		module_level,
		multiplier_lv1,
		multiplier_lv2,
		multiplier_lv3
	)

func _get_additive() -> float:
	return WeaponModuleRuntimeUtils.get_value_by_level(
		module_level,
		additive_lv1,
		additive_lv2,
		additive_lv3
	)
