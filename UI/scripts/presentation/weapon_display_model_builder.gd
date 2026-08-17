extends RefCounted
class_name WeaponDisplayModelBuilder

const DISPLAY_MODEL := preload("res://UI/scripts/presentation/weapon_display_model.gd")
const STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const RARITY_UTIL := preload("res://data/LootRarity.gd")


static func build_from_definition(definition: WeaponDefinition, preview_level: int = 1):
	var model = DISPLAY_MODEL.new()
	if definition == null:
		return model
	_populate_definition(model, definition)
	if definition.scene == null:
		return model
	var weapon := definition.scene.instantiate() as Weapon
	if weapon == null:
		return model
	_populate_instance_fields(model, weapon, preview_level, false)
	weapon.queue_free()
	return model


static func build_from_instance(weapon: Weapon, include_next_level: bool = false, location: String = ""):
	var model = DISPLAY_MODEL.new()
	if weapon == null or not is_instance_valid(weapon):
		return model
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if definition != null:
		_populate_definition(model, definition)
	else:
		model.weapon_id = weapon_id
		model.display_name = LocalizationManager.get_weapon_instance_display_name(weapon)
		model.base_name = model.display_name
	_populate_instance_fields(model, weapon, int(weapon.level), include_next_level)
	model.display_name = LocalizationManager.get_weapon_instance_display_name(weapon)
	model.location = location
	return model


static func build_at_levels(definition: WeaponDefinition, current_level: int, next_level: int):
	var model: Variant = build_from_definition(definition, current_level)
	if definition == null or definition.scene == null:
		return model
	var weapon := definition.scene.instantiate() as Weapon
	if weapon == null:
		return model
	var data_variant: Variant = weapon.get("weapon_data")
	if data_variant is Dictionary:
		model.current_stats = weapon.get_weapon_level_data(current_level, data_variant as Dictionary)
		model.next_stats = weapon.get_weapon_level_data(next_level, data_variant as Dictionary)
		model.upgrade_deltas = STAT_FORMATTER.build_deltas(model.current_stats, model.next_stats)
	model.level = current_level
	model.max_level = int(weapon.max_level)
	weapon.queue_free()
	return model


static func _populate_definition(model, definition: WeaponDefinition) -> void:
	model.weapon_id = str(definition.weapon_id)
	model.base_name = LocalizationManager.get_weapon_name_from_definition(definition)
	model.display_name = model.base_name
	model.description = LocalizationManager.get_weapon_description_from_definition(definition)
	model.icon = definition.icon
	model.rarity = definition.get_rarity()
	model.price = int(definition.price)
	model.available_branches.clear()
	for branch_definition in DataHandler.read_weapon_branch_options(str(definition.scene_path), 999):
		if branch_definition == null:
			continue
		model.available_branches.append({
			"id": str(branch_definition.branch_id),
			"name": LocalizationManager.get_branch_display_name(branch_definition),
			"description": LocalizationManager.get_branch_description(branch_definition),
			"unlock_fuse": int(branch_definition.unlock_fuse),
			"icon": branch_definition.icon,
		})


static func _populate_instance_fields(model, weapon: Weapon, level: int, include_next_level: bool) -> void:
	model.level = level
	model.max_level = int(weapon.max_level)
	model.fuse = int(weapon.fuse)
	model.module_capacity = weapon.module_slot_capacity
	model.module_count = weapon.modules.get_child_count() if weapon.modules != null else 0
	model.icon = weapon.sprite.texture if model.icon == null and weapon.sprite != null else model.icon
	model.traits = _string_name_array_to_strings(weapon.get_explicit_weapon_traits())
	model.delivery_types = _string_name_array_to_strings(weapon.get_explicit_delivery_types())
	model.capabilities = _string_name_array_to_strings(weapon.get_explicit_weapon_capabilities())
	model.taxonomy_labels = _localize_taxonomy(model.traits, model.delivery_types, model.capabilities)
	var data_variant: Variant = weapon.get("weapon_data")
	if data_variant is Dictionary:
		model.current_stats = weapon.get_weapon_level_data(level, data_variant as Dictionary)
		if include_next_level and level < int(weapon.max_level):
			model.next_stats = weapon.get_weapon_level_data(level + 1, data_variant as Dictionary)
			model.upgrade_deltas = STAT_FORMATTER.build_deltas(model.current_stats, model.next_stats)
	_populate_selected_branches(model, weapon)


static func _populate_selected_branches(model, weapon: Weapon) -> void:
	model.selected_branches.clear()
	var runtime: WeaponBranchRuntime = weapon.branch_runtime
	if runtime == null:
		return
	for branch_id_variant in runtime.branch_ids:
		var branch_id := str(branch_id_variant)
		var definition := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, branch_id)
		model.selected_branches.append({
			"id": branch_id,
			"name": LocalizationManager.get_branch_display_name(definition) if definition != null else branch_id,
			"description": LocalizationManager.get_branch_description(definition) if definition != null else "",
		})


static func _localize_taxonomy(traits: PackedStringArray, delivery_types: PackedStringArray, capabilities: PackedStringArray) -> PackedStringArray:
	var labels := PackedStringArray()
	for values in [traits, delivery_types, capabilities]:
		for value in values:
			var label := LocalizationManager.get_module_term(StringName(value), value.replace("_", " ").capitalize())
			if label != "" and not labels.has(label):
				labels.append(label)
	return labels


static func _string_name_array_to_strings(values: Array) -> PackedStringArray:
	var output := PackedStringArray()
	for value in values:
		output.append(str(value))
	return output
