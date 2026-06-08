extends RefCounted
class_name WeaponStatPipeline

var weapon: Weapon
var runtime_trait_overrides: Array[StringName] = []
var last_stat_snapshot: Dictionary = {}
var external_damage_mul_modifiers: Dictionary = {}

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func get_normalized_weapon_traits() -> Array[StringName]:
	var traits: Array[StringName] = _get_modules_container().get_normalized_weapon_traits()
	for runtime_trait in runtime_trait_overrides:
		if not traits.has(runtime_trait):
			traits.append(runtime_trait)
	if weapon.supports_projectiles() and not traits.has(CombatTrait.PROJECTILE):
		traits.append(CombatTrait.PROJECTILE)
	if weapon.supports_melee_contact() and not traits.has(CombatTrait.MELEE):
		traits.append(CombatTrait.MELEE)
	return traits

func get_explicit_weapon_traits() -> Array[StringName]:
	var traits: Array[StringName] = _get_modules_container().get_normalized_weapon_traits()
	for runtime_trait in runtime_trait_overrides:
		if not traits.has(runtime_trait):
			traits.append(runtime_trait)
	return traits

func add_runtime_weapon_trait(trait_name: Variant) -> void:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return
	if runtime_trait_overrides.has(normalized):
		return
	runtime_trait_overrides.append(normalized)
	weapon.calculate_status()

func remove_runtime_weapon_trait(trait_name: Variant) -> void:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return
	if not runtime_trait_overrides.has(normalized):
		return
	runtime_trait_overrides.erase(normalized)
	weapon.calculate_status()

func clear_runtime_weapon_traits() -> void:
	if runtime_trait_overrides.is_empty():
		return
	runtime_trait_overrides.clear()
	weapon.calculate_status()

func has_weapon_trait(trait_name: Variant) -> bool:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return false
	return get_normalized_weapon_traits().has(normalized)

func has_any_weapon_traits(required_traits: Array[StringName]) -> bool:
	if required_traits.is_empty():
		return true
	var traits := get_normalized_weapon_traits()
	for required_trait in required_traits:
		if traits.has(required_trait):
			return true
	return false

func has_any_explicit_weapon_traits(required_traits: Array[StringName]) -> bool:
	if required_traits.is_empty():
		return true
	var traits := get_explicit_weapon_traits()
	for required_trait in required_traits:
		if traits.has(required_trait):
			return true
	return false

func validate_module_compatibility() -> void:
	for child in _get_modules_container().get_children():
		var module_node := child as Module
		if module_node == null:
			continue
		module_node.weapon = weapon
		if module_node.can_apply_to_weapon(weapon):
			continue
		push_warning(
			"Module '%s' is incompatible with weapon '%s'; removing module." %
			[module_node.name, weapon.name]
		)
		module_node.call_deferred("queue_free")

func get_module_count() -> int:
	var count := 0
	for child in _get_modules_container().get_children():
		if child is Module:
			count += 1
	return count

func get_available_module_slots() -> int:
	return max(0, int(weapon.MAX_MODULE_NUMBER) - get_module_count())

func get_equipped_modules() -> Array[Module]:
	var output: Array[Module] = []
	for child in _get_modules_container().get_children():
		var module_node := child as Module
		if module_node:
			output.append(module_node)
	return output

func build_stat_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	var tracked_stats: PackedStringArray = [
		"damage",
		"attack_cooldown",
		"projectile_hits",
		"speed",
		"size",
		"hp",
		"dash_speed",
		"return_speed",
		"attack_range",
		"heat_per_shot",
		"heat_max_value",
		"heat_cool_rate",
	]
	for stat_key in tracked_stats:
		if weapon.get(stat_key) != null:
			snapshot[stat_key] = float(weapon.get(stat_key))
	return snapshot

func get_last_stat_snapshot() -> Dictionary:
	return last_stat_snapshot.duplicate(true)

func get_runtime_stat_value(stat_name: String, base_value: float) -> float:
	var sanitized_base := maxf(base_value, 0.0)
	var additive_total := 0.0
	var multiplier_delta_total := 0.0
	for module_node in get_equipped_modules():
		var base_eval := module_node.apply_stat_modifiers({stat_name: sanitized_base})
		var zero_eval := module_node.apply_stat_modifiers({stat_name: 0.0})
		var value_on_base := float(base_eval.get(stat_name, sanitized_base))
		var value_on_zero := float(zero_eval.get(stat_name, 0.0))
		additive_total += value_on_zero
		if sanitized_base > 0.0:
			var multiplier_component := (value_on_base - value_on_zero) / sanitized_base
			multiplier_delta_total += (multiplier_component - 1.0)
	var pre_mult_value := sanitized_base + additive_total
	var final_mult := maxf(0.0, 1.0 + multiplier_delta_total)
	return pre_mult_value * final_mult

func get_runtime_damage_value(base_damage_value: float) -> int:
	var runtime_damage := get_runtime_stat_value("damage", base_damage_value)
	runtime_damage *= get_total_external_damage_mul()
	return max(1, int(round(runtime_damage)))

func apply_external_damage_mul(source_id: StringName, mul: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := maxf(mul, 0.05)
	external_damage_mul_modifiers[source_id] = clamped_mul
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
		PlayerData.player.call(
			"notify_weapon_status_change",
			&"weapon_damage_up" if clamped_mul >= 1.0 else &"weapon_damage_down",
			source_id,
			true
		)

func remove_external_damage_mul(source_id: StringName) -> void:
	if external_damage_mul_modifiers.has(source_id):
		var prev_mul := float(external_damage_mul_modifiers.get(source_id, 1.0))
		external_damage_mul_modifiers.erase(source_id)
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
			PlayerData.player.call(
				"notify_weapon_status_change",
				&"weapon_damage_up" if prev_mul >= 1.0 else &"weapon_damage_down",
				source_id,
				false
			)

func get_total_external_damage_mul() -> float:
	var total := 1.0
	for mul in external_damage_mul_modifiers.values():
		total *= float(mul)
	return maxf(total, 0.05)

func get_projected_stats_with_module(module_instance: Module) -> Dictionary:
	var projected := build_stat_snapshot()
	if module_instance == null:
		return projected
	return module_instance.apply_stat_modifiers(projected)

func apply_module_stat_pipeline() -> void:
	var stats := build_stat_snapshot()
	for module_node in get_equipped_modules():
		stats = module_node.apply_stat_modifiers(stats)
	apply_stat_snapshot(stats)
	last_stat_snapshot = stats.duplicate(true)

func clear_for_weapon_exit() -> void:
	runtime_trait_overrides.clear()
	last_stat_snapshot.clear()
	external_damage_mul_modifiers.clear()

func apply_stat_snapshot(snapshot: Dictionary) -> void:
	if snapshot == null:
		return
	for stat_key in snapshot.keys():
		var stat_name := str(stat_key)
		if weapon.get(stat_name) == null:
			continue
		var current_value: Variant = weapon.get(stat_name)
		var next_value: Variant = snapshot[stat_key]
		if typeof(current_value) == TYPE_INT:
			weapon.set(stat_name, int(round(float(next_value))))
		else:
			weapon.set(stat_name, float(next_value))
	if weapon.get("cooldown_timer") != null and weapon.get("attack_cooldown") != null:
		var timer_variant: Variant = weapon.get("cooldown_timer")
		if timer_variant is Timer and float(weapon.get("attack_cooldown")) > 0.0:
			(timer_variant as Timer).wait_time = float(weapon.get("attack_cooldown"))
	if weapon.has_method("apply_size_multiplier") and weapon.get("size") != null:
		weapon.call("apply_size_multiplier", float(weapon.get("size")))
	if snapshot.has("heat_per_shot") or snapshot.has("heat_max_value") or snapshot.has("heat_cool_rate"):
		weapon.configure_heat(weapon.heat_per_shot, weapon.heat_max_value, weapon.heat_cool_rate)

func _get_modules_container() -> WeaponModules:
	return weapon.modules
