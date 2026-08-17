extends RefCounted
class_name RewardWeaponPreviewData

const DAMAGE_STYLE := preload("res://UI/labels/damage_label_style_profile.tres")

const DAMAGE_TAGS: Array[StringName] = [&"physical", &"energy", &"fire", &"freeze"]


static func build(reward: RewardInfo) -> Dictionary:
	if reward == null:
		return {}
	var weapon_id := _weapon_id(reward)
	var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	if definition == null or definition.scene == null:
		return {}
	var weapon := definition.scene.instantiate() as Weapon
	if weapon == null:
		return {}
	var preview_fuse := 1
	var acquired_ids: Array[String] = []
	var outcome := _prediction(weapon_id)
	var equipped := outcome.get("weapon", null) as Weapon
	if equipped != null and is_instance_valid(equipped):
		preview_fuse = int(outcome.get("target_fuse", equipped.fuse))
		if equipped.branch_runtime != null:
			acquired_ids.assign(equipped.branch_runtime.branch_ids)
	elif reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		preview_fuse = 1
	var installation_requirements := _installation_requirements(weapon)
	var damage_types := _weapon_damage_types(weapon)
	var branches := _branch_previews(definition, weapon, preview_fuse, acquired_ids)
	weapon.free()
	return {
		"weapon_id": weapon_id,
		"preview_fuse": preview_fuse,
		"installation_requirements": installation_requirements,
		"damage_types": damage_types,
		"branches": branches,
	}


static func damage_color(type_name: StringName) -> Color:
	return DAMAGE_STYLE.get_color(type_name, false)


static func _weapon_id(reward: RewardInfo) -> String:
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return reward.target_weapon_id.strip_edges()
	return reward.item_id.strip_edges()


static func _prediction(weapon_id: String) -> Dictionary:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return {}
	if not PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
		return {}
	return PlayerData.player.predict_auto_fuse_weapon_obtain(weapon_id)


static func _installation_requirements(weapon: Weapon) -> Array[StringName]:
	var output: Array[StringName] = []
	if weapon is Melee:
		output.append(&"melee_weapon")
	elif weapon is Ranger:
		output.append(&"ranged_weapon")
	for delivery_type in weapon.get_explicit_delivery_types():
		if not output.has(delivery_type):
			output.append(delivery_type)
	for capability in weapon.get_explicit_weapon_capabilities():
		if not output.has(capability):
			output.append(capability)
	if weapon.uses_ammo_system():
		output.append(&"uses_ammo")
	return output


static func _weapon_damage_types(weapon: Weapon) -> Array[StringName]:
	var output: Array[StringName] = []
	for tag in weapon.get_explicit_weapon_traits():
		if DAMAGE_TAGS.has(tag) and not output.has(tag):
			output.append(tag)
	if output.is_empty():
		output.append(&"physical")
	return output.slice(0, mini(2, output.size()))


static func _branch_previews(
	definition: WeaponDefinition,
	weapon: Weapon,
	preview_fuse: int,
	acquired_ids: Array[String]
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var fallback_types := weapon.get_explicit_weapon_traits()
	for branch_def in DataHandler.read_weapon_branch_options(definition.scene_path, 999):
		if branch_def == null:
			continue
		var damage_types := _branch_damage_types(branch_def, fallback_types)
		var acquired := acquired_ids.has(branch_def.branch_id)
		var unlocked := acquired or preview_fuse >= int(branch_def.unlock_fuse)
		var description := LocalizationManager.get_branch_description(branch_def)
		output.append({
			"id": branch_def.branch_id,
			"name": LocalizationManager.get_branch_display_name(branch_def),
			"description": description if unlocked else _hide_numbers(description),
			"damage_types": damage_types,
			"unlock_fuse": int(branch_def.unlock_fuse),
			"state": &"acquired" if acquired else (&"available" if unlocked else &"locked"),
			"numbers_hidden": not unlocked,
		})
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := DataHandler.read_weapon_branch_definition(definition.scene_path, str(a.get("id", "")))
		var right := DataHandler.read_weapon_branch_definition(definition.scene_path, str(b.get("id", "")))
		return int(left.sort_order if left != null else 0) < int(right.sort_order if right != null else 0)
	)
	return output.slice(0, mini(2, output.size()))


static func _branch_damage_types(branch_def: WeaponBranchDefinition, fallback_types: Array[StringName]) -> Array[StringName]:
	var output: Array[StringName] = []
	for tag in branch_def.produces_tags:
		if DAMAGE_TAGS.has(tag) and not output.has(tag):
			output.append(tag)
	if output.is_empty():
		for tag in fallback_types:
			if DAMAGE_TAGS.has(tag) and not output.has(tag):
				output.append(tag)
	if output.is_empty():
		output.append(&"physical")
	return output.slice(0, mini(2, output.size()))


static func _hide_numbers(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[+-]?[0-9]+(?:[.][0-9]+)?%?")
	return regex.sub(text, "—", true)
