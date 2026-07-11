extends RefCounted
class_name WeaponPassivePresenter

var _passive_meta_cache: Dictionary = {}

func get_equipped_weapon_passive_statuses() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if PlayerData.player_weapon_list == null:
		return output
	for weapon_index in range(PlayerData.player_weapon_list.size()):
		var weapon_variant: Variant = PlayerData.player_weapon_list[weapon_index]
		var weapon := weapon_variant as Node
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("get_passive_status"):
			continue
		var status_variant: Variant = weapon.call("get_passive_status")
		if not (status_variant is Dictionary):
			continue
		output.append(_build_presenter_status(weapon, weapon_index, status_variant as Dictionary))
	return output

func _build_presenter_status(weapon: Node, weapon_index: int, passive_status: Dictionary) -> Dictionary:
	var is_main := _is_main_weapon(weapon, weapon_index)
	var passive_id := str(passive_status.get("id", ""))
	var passive_meta := _get_passive_meta(passive_id)
	var state := str(passive_status.get("state", "inactive"))
	var ready := bool(passive_status.get("ready", false))
	var inactive_reason := str(passive_status.get("inactive_reason", ""))
	if not is_main:
		state = "inactive"
		ready = false
		inactive_reason = "not_main_weapon"
	return {
		"weapon_id": _get_weapon_id(weapon),
		"weapon_name": _get_weapon_name(weapon),
		"passive_id": passive_id,
		"passive_name": _get_localized_passive_name(passive_meta, str(passive_status.get("display_name", ""))),
		"description": _get_localized_passive_description(passive_meta),
		"icon": _get_meta_value(passive_meta, "icon", null),
		"condition_type": _get_meta_string(passive_meta, "condition_type", str(passive_status.get("condition_type", ""))),
		"refresh_type": _get_meta_string(passive_meta, "refresh_type", str(passive_status.get("refresh_hint", ""))),
		"ui_mode": _get_meta_string(passive_meta, "ui_mode", "state"),
		"is_main_weapon": is_main,
		"state": state,
		"progress": _get_float_or_default(passive_status, "progress", -1.0),
		"current": passive_status.get("current", null),
		"required": passive_status.get("required", null),
		"ready": ready,
		"charge_current": int(passive_status.get("charge_current", passive_status.get("charges_current", 1 if ready else 0))),
		"charge_max": int(passive_status.get("charge_max", passive_status.get("charges_max", 1))),
		"charge_based": bool(passive_status.get("charge_based", true)),
		"trigger_hint": str(passive_status.get("trigger_hint", "")),
		"refresh_hint": str(passive_status.get("refresh_hint", "")),
		"radial_projectile_count": passive_status.get("radial_projectile_count", 0),
		"inactive_reason": inactive_reason,
	}

func _get_passive_meta(passive_id: String) -> Resource:
	if passive_id.strip_edges() == "":
		return null
	if _passive_meta_cache.has(passive_id):
		return _passive_meta_cache[passive_id] as Resource
	if DataHandler == null or not DataHandler.has_method("read_weapon_passive_branch_definition"):
		return null
	var meta_variant: Variant = DataHandler.call("read_weapon_passive_branch_definition", passive_id)
	var meta := meta_variant as Resource
	_passive_meta_cache[passive_id] = meta
	return meta

func _get_meta_string(meta: Resource, key: String, fallback: String) -> String:
	if meta == null:
		return fallback
	var value: Variant = meta.get(key)
	if value == null:
		return fallback
	var text := str(value)
	return fallback if text.strip_edges() == "" else text

func _get_meta_value(meta: Resource, key: String, fallback: Variant) -> Variant:
	if meta == null:
		return fallback
	var value: Variant = meta.get(key)
	return fallback if value == null else value


func _get_localized_passive_name(meta: Resource, fallback: String) -> String:
	if meta is WeaponPassiveBranchDefinition and LocalizationManager != null:
		return LocalizationManager.get_weapon_passive_display_name(meta as WeaponPassiveBranchDefinition)
	return _get_meta_string(meta, "display_name", fallback)


func _get_localized_passive_description(meta: Resource) -> String:
	if meta is WeaponPassiveBranchDefinition and LocalizationManager != null:
		return LocalizationManager.get_weapon_passive_description(meta as WeaponPassiveBranchDefinition)
	return _get_meta_string(meta, "description", "")


func _is_main_weapon(weapon: Node, weapon_index: int) -> bool:
	if weapon.has_method("is_main_weapon"):
		return bool(weapon.call("is_main_weapon"))
	return weapon_index == PlayerData.main_weapon_index

func _get_weapon_id(weapon: Node) -> String:
	if weapon is Weapon and DataHandler != null and DataHandler.has_method("get_weapon_id_from_instance"):
		var id := str(DataHandler.call("get_weapon_id_from_instance", weapon))
		if id.strip_edges() != "":
			return id
	return str(weapon.get_instance_id())

func _get_weapon_name(weapon: Node) -> String:
	if weapon is Weapon and LocalizationManager != null and LocalizationManager.has_method("get_weapon_instance_display_name"):
		var localized_name := str(LocalizationManager.call("get_weapon_instance_display_name", weapon))
		if localized_name.strip_edges() != "":
			return localized_name
	var item_name: Variant = weapon.get("ITEM_NAME")
	if item_name != null and str(item_name).strip_edges() != "":
		return str(item_name)
	return weapon.name

func _get_float_or_default(source: Dictionary, key: String, fallback: float) -> float:
	if not source.has(key):
		return fallback
	var value: Variant = source.get(key)
	if value == null:
		return fallback
	return float(value)
