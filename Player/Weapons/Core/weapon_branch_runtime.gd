extends Node
class_name WeaponBranchRuntime

var weapon: Weapon
var branch_ids: Array[String] = []
var branch_definitions: Array[WeaponBranchDefinition] = []
var branch_behaviors: Array[WeaponBranchBehavior] = []

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func set_branch(new_branch_id: String) -> bool:
	return add_branch(new_branch_id)

func add_branch(new_branch_id: String) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	var normalized_id := str(new_branch_id)
	if normalized_id == "":
		return false
	if has_branch(normalized_id):
		return false
	var branch_def: WeaponBranchDefinition = DataHandler.read_weapon_branch_definition(weapon.scene_file_path, normalized_id)
	if branch_def == null:
		return false
	if weapon.fuse < int(branch_def.unlock_fuse):
		return false
	if not is_branch_compatible_with_existing(branch_def):
		return false
	branch_ids.append(normalized_id)
	branch_definitions.append(branch_def)
	_apply_branch_behavior_for_definition(branch_def, normalized_id)
	_refresh_weapon_after_branch_change()
	return true

func restore_branch_ids(saved_branch_ids: Array) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	_clear_branch_behaviors()
	branch_ids.clear()
	branch_definitions.clear()
	for branch_id_variant in saved_branch_ids:
		if branch_ids.size() >= 2:
			push_warning("Skipping extra saved branch '%s' on weapon '%s'." % [str(branch_id_variant), weapon.name])
			continue
		var saved_branch_id := str(branch_id_variant).strip_edges()
		if saved_branch_id == "":
			continue
		var def := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, saved_branch_id)
		if def == null:
			push_warning("Skipping missing saved branch '%s' on weapon '%s'." % [saved_branch_id, weapon.name])
			continue
		if int(weapon.fuse) < int(def.unlock_fuse):
			push_warning("Skipping saved branch '%s' because fuse %d is below unlock fuse %d." % [saved_branch_id, int(weapon.fuse), int(def.unlock_fuse)])
			continue
		if not is_branch_compatible_with_existing(def):
			push_warning("Skipping incompatible saved branch '%s' on weapon '%s'." % [saved_branch_id, weapon.name])
			continue
		branch_ids.append(saved_branch_id)
		branch_definitions.append(def)
		_apply_branch_behavior_for_definition(def, saved_branch_id)
	_refresh_weapon_after_branch_change()

func has_branch(check_branch_id: String) -> bool:
	var normalized_id := str(check_branch_id)
	if normalized_id == "":
		return false
	for existing_id in branch_ids:
		if str(existing_id) == normalized_id:
			return true
	return false

func get_branch_options() -> Array[WeaponBranchDefinition]:
	return get_available_branch_options()

func get_available_branch_options() -> Array[WeaponBranchDefinition]:
	if weapon == null or not is_instance_valid(weapon):
		return []
	return get_available_branch_options_for_fuse(weapon.fuse)

func get_available_branch_options_for_fuse(target_fuse: int) -> Array[WeaponBranchDefinition]:
	if weapon == null or not is_instance_valid(weapon):
		return []
	if not _can_choose_more_branches():
		return []
	var output: Array[WeaponBranchDefinition] = []
	var options := DataHandler.read_weapon_branch_options(weapon.scene_file_path, target_fuse)
	for def in options:
		if def == null:
			continue
		if has_branch(def.branch_id):
			continue
		if not is_branch_compatible_with_existing(def):
			continue
		output.append(def)
	return output

func is_branch_compatible_with_existing(candidate_def: WeaponBranchDefinition) -> bool:
	return get_branch_incompatibility_reason(candidate_def) == ""

func get_branch_incompatibility_reason(candidate_def: WeaponBranchDefinition) -> String:
	if candidate_def == null:
		return "invalid"
	var candidate_id := str(candidate_def.branch_id)
	if candidate_id == "":
		return "invalid"
	if has_branch(candidate_id):
		return "duplicate"
	for i in range(branch_ids.size()):
		var existing_id := str(branch_ids[i])
		if existing_id == "":
			continue
		var existing_def := _get_branch_definition_for_index(i, existing_id)
		if existing_def == null:
			continue
		if _branch_lists_id(candidate_def.incompatible_branch_ids, existing_id):
			return "incompatible"
		if _branch_lists_id(existing_def.incompatible_branch_ids, candidate_id):
			return "incompatible"
		if _branch_groups_overlap(candidate_def.exclusive_groups, existing_def.exclusive_groups):
			return "exclusive_group"
	return ""

func get_branch_behaviors() -> Array[WeaponBranchBehavior]:
	var output: Array[WeaponBranchBehavior] = []
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior):
			output.append(behavior)
	return output

func notify_branch_level_applied(applied_level: int) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_level_applied(applied_level)

func notify_branch_weapon_shot(base_direction: Vector2) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_weapon_shot(base_direction)

func notify_branch_target_hit(target: Node) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_target_hit(target)

func notify_branch_passive_event(event_name: StringName, detail: Dictionary) -> void:
	for behavior in get_branch_behaviors():
		behavior.on_passive_event(event_name, detail)

func get_branch_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var directions: Array[Vector2] = [base_direction]
	for behavior in get_branch_behaviors():
		var next_directions: Array[Vector2] = []
		for direction in directions:
			var branch_dirs := behavior.get_shot_directions(direction, shot_count)
			if branch_dirs.is_empty():
				next_directions.append(direction)
			else:
				next_directions.append_array(branch_dirs)
		directions = next_directions
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("get_module_shot_directions"):
		var base_module_count := directions.size()
		if shot_count > 0:
			base_module_count = maxi(base_module_count, shot_count)
		var module_directions: Array[Vector2] = weapon.call(
			"get_module_shot_directions",
			base_direction,
			base_module_count
		)
		if module_directions.size() > directions.size():
			directions = module_directions
	return directions

func get_branch_cooldown_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_cooldown_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_projectile_damage_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_projectile_damage_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_projectile_hit_override(current_hits: int) -> int:
	var hits: int = max(1, current_hits)
	for behavior in get_branch_behaviors():
		hits = max(1, behavior.get_projectile_hit_override(hits))
	return hits

func get_branch_damage_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_damage_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_attack_range_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_attack_range_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_dash_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_dash_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_return_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_return_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_extra_heat_shot_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= clampf(behavior.get_extra_heat_shot_multiplier(), 0.0, 1.0)
	return clampf(multiplier, 0.0, 1.0)

func get_branch_orbit_spin_speed_multiplier() -> float:
	var multiplier := 1.0
	for behavior in get_branch_behaviors():
		multiplier *= maxf(behavior.get_orbit_spin_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func get_branch_pierce_damage_gain_per_hit() -> int:
	var total := 0
	for behavior in get_branch_behaviors():
		total += max(0, behavior.get_pierce_damage_gain_per_hit())
	return total

func get_branch_max_pierce_damage_stacks() -> int:
	var max_stacks := 0
	for behavior in get_branch_behaviors():
		max_stacks = max(max_stacks, behavior.get_max_pierce_damage_stacks())
	return max_stacks

func get_branch_damage_type_override(default_type: StringName = Attack.TYPE_PHYSICAL) -> StringName:
	var resolved_type := default_type
	for behavior in get_branch_behaviors():
		var next_type := Attack.normalize_damage_type(behavior.get_damage_type_override())
		if next_type != Attack.TYPE_PHYSICAL:
			resolved_type = next_type
	return resolved_type

func apply_branch_explosion_modifiers(config: ExplosionEffectConfig) -> void:
	for behavior in get_branch_behaviors():
		behavior.modify_explosion_config(config)

func apply_branch_behaviors_if_needed(force_refresh: bool = false) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if force_refresh:
		_clear_branch_behaviors()
	_adopt_existing_branch_behavior_children()
	for i in range(branch_ids.size()):
		var current_id := str(branch_ids[i])
		if current_id == "":
			continue
		if _has_branch_behavior(current_id):
			continue
		var def: WeaponBranchDefinition = null
		if i < branch_definitions.size():
			def = branch_definitions[i]
		if def == null:
			def = DataHandler.read_weapon_branch_definition(weapon.scene_file_path, current_id)
			if def != null:
				while branch_definitions.size() <= i:
					branch_definitions.append(null)
				branch_definitions[i] = def
		if def == null:
			continue
		_apply_branch_behavior_for_definition(def, current_id)

func clear_branch_behaviors() -> void:
	_clear_branch_behaviors()

func clear_for_weapon_exit() -> void:
	branch_behaviors.clear()
	branch_definitions.clear()

func _can_choose_more_branches() -> bool:
	return branch_ids.size() < 2

func _get_branch_definition_for_index(index: int, fallback_branch_id: String) -> WeaponBranchDefinition:
	if index >= 0 and index < branch_definitions.size():
		var existing_def := branch_definitions[index]
		if existing_def != null:
			return existing_def
	if weapon == null or not is_instance_valid(weapon):
		return null
	return DataHandler.read_weapon_branch_definition(weapon.scene_file_path, fallback_branch_id)

func _branch_lists_id(branch_id_list: PackedStringArray, lookup_id: String) -> bool:
	var normalized_lookup := str(lookup_id)
	if normalized_lookup == "":
		return false
	for item in branch_id_list:
		if str(item) == normalized_lookup:
			return true
	return false

func _branch_groups_overlap(a: PackedStringArray, b: PackedStringArray) -> bool:
	for group_a in a:
		var normalized_group := str(group_a).strip_edges()
		if normalized_group == "":
			continue
		for group_b in b:
			if normalized_group == str(group_b).strip_edges():
				return true
	return false

func _apply_branch_behavior_for_definition(def: WeaponBranchDefinition, id: String) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if def == null or def.behavior_scene == null:
		return
	var behavior_instance := def.behavior_scene.instantiate() as WeaponBranchBehavior
	if behavior_instance == null:
		push_warning("Weapon branch '%s' behavior is not WeaponBranchBehavior on weapon '%s'." % [id, weapon.name])
		return
	behavior_instance.name = "Branch_%s" % id
	behavior_instance.set_meta("branch_id", id)
	branch_behaviors.append(behavior_instance)
	weapon.add_child(behavior_instance)
	behavior_instance.setup(weapon)
	behavior_instance.on_weapon_ready()

func _has_branch_behavior(id: String) -> bool:
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior) and str(behavior.get_meta("branch_id", "")) == id:
			return true
	return false

func _adopt_existing_branch_behavior_children() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	for child in weapon.get_children():
		var existing := child as WeaponBranchBehavior
		if existing == null or branch_behaviors.has(existing):
			continue
		var existing_id := str(existing.get_meta("branch_id", ""))
		if existing_id == "" or not branch_ids.has(existing_id):
			continue
		existing.setup(weapon)
		branch_behaviors.append(existing)

func _clear_branch_behaviors() -> void:
	for behavior in branch_behaviors:
		if behavior and is_instance_valid(behavior):
			var source_id := behavior.get_runtime_classification_source_id()
			behavior.on_removed()
			weapon.clear_runtime_weapon_traits(source_id)
			weapon.clear_runtime_delivery_types(source_id)
			weapon.clear_runtime_weapon_capabilities(source_id)
			behavior.queue_free()
	branch_behaviors.clear()

func _refresh_weapon_after_branch_change() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("set_level") and weapon.level > 0:
		weapon.set_level(clampi(weapon.level, 1, weapon.max_level))
	else:
		weapon.calculate_status()
