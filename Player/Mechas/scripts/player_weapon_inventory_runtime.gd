extends RefCounted
class_name PlayerWeaponInventoryRuntime

const PREVIEW_FORMATTER := preload("res://UI/scripts/weapon_obtain_preview_formatter.gd")

var _player
var _weapon_list_dirty := true
var _weapon_roles_dirty := true
var _weapon_orbit_states_dirty := true
var _weapon_orbit_force_reset := true
var _tracked_weapon_exit_ids: Dictionary = {}

func setup(player) -> void:
	_player = player

func create_weapon(item_id, level := 1, auto_fuse := false) -> void:
	if _player == null:
		return
	var player_data = _player.PlayerData
	var weapon: Weapon
	var incoming_weapon_id := ""
	if item_id is String:
		incoming_weapon_id = str(item_id).strip_edges()
		if auto_fuse or find_equipped_weapon_by_id(incoming_weapon_id) != null:
			var auto_fuse_result := try_auto_fuse_weapon_obtain(incoming_weapon_id)
			var result_type := str(auto_fuse_result.get("result", "not_applicable"))
			if result_type == "fused" or result_type == "converted_to_gold":
				return
		var weapon_def := DataHandler.read_weapon_data(incoming_weapon_id) as WeaponDefinition
		if weapon_def == null:
			push_warning("create_weapon failed: weapon id %s not found." % str(item_id))
			return
		weapon = weapon_def.scene.instantiate() as Weapon
		if weapon == null:
			push_warning("create_weapon failed: weapon scene instantiate returned null for id %s." % incoming_weapon_id)
			return
		weapon.level = int(level)
	else:
		weapon = item_id as Weapon
		if weapon == null or not is_instance_valid(weapon):
			push_warning("create_weapon failed: invalid weapon instance input.")
			return
		incoming_weapon_id = DataHandler.get_weapon_id_from_instance(weapon)

	if player_data.player_weapon_list.size() >= player_data.max_weapon_num:
		var ui = GlobalVariables.ui
		if ui and is_instance_valid(ui) and ui.has_method("request_weapon_replacement"):
			ui.call("request_weapon_replacement", weapon)
		else:
			push_warning("Weapon bar is full and no replacement UI is available.")
			weapon.queue_free()
		refresh_weapon_related_ui()
		return

	_player._attach_weapon_to_equipped_holder(weapon)
	weapon.position = Vector2.ZERO
	player_data.player_weapon_list.append(weapon)
	if player_data.player_weapon_list.size() == 1:
		player_data.set_main_weapon_index(0)
	player_data.notify_weapon_list_changed()
	player_data.record_weapon_progress()
	mark_weapon_structure_dirty(true)
	refresh_weapon_structure_if_needed()
	_player._rebuild_shared_heat_pool()
	refresh_weapon_related_ui()

func try_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
	if _player == null:
		return {"result": "invalid", "weapon_id": weapon_id}
	var player_data = _player.PlayerData
	var prediction := predict_auto_fuse_weapon_obtain(weapon_id)
	var result_type := str(prediction.get("result", "not_applicable"))
	if result_type == "not_applicable" or result_type == "invalid":
		return prediction
	var subject := prediction.get("weapon", null) as Weapon
	if subject == null or not is_instance_valid(subject):
		return {"result": "invalid", "weapon_id": weapon_id}
	if result_type == "fused":
		player_data.record_weapon_progress()
		var target_fuse := int(prediction.get("target_fuse", int(subject.fuse)))
		subject.fuse = target_fuse
		if subject.has_method("refresh_max_level_from_data"):
			subject.call("refresh_max_level_from_data")
		var clamped_level := clampi(int(subject.level), 1, int(subject.max_level))
		if subject.has_method("set_level"):
			subject.call("set_level", clamped_level)
		else:
			subject.level = clamped_level
			if subject.has_method("calculate_status"):
				subject.call("calculate_status")
		try_prompt_branch_selection(subject, target_fuse)
	elif result_type == "converted_to_gold":
		var converted_gold := int(prediction.get("gold", 0))
		player_data.recycle_gold(converted_gold)
	notify_weapon_duplicate_result(subject, weapon_id, prediction)
	refresh_weapon_related_ui()
	return prediction

func predict_auto_fuse_weapon_obtain(weapon_id: String) -> Dictionary:
	var normalized_id := str(weapon_id).strip_edges()
	if normalized_id == "":
		return {"result": "invalid", "weapon_id": normalized_id}
	var equipped_weapon := find_equipped_weapon_by_id(normalized_id)
	if equipped_weapon == null:
		return {"result": "not_applicable", "weapon_id": normalized_id}
	var max_fuse: int = max(1, int(equipped_weapon.FINAL_MAX_FUSE))
	if int(equipped_weapon.fuse) < max_fuse:
		var target_fuse := int(equipped_weapon.fuse) + 1
		return {
			"result": "fused",
			"weapon_id": normalized_id,
			"weapon": equipped_weapon,
			"from_fuse": int(equipped_weapon.fuse),
			"target_fuse": target_fuse,
			"has_branch_options": has_branch_options_for_fuse(equipped_weapon, target_fuse),
		}
	return {
		"result": "converted_to_gold",
		"weapon_id": normalized_id,
		"weapon": equipped_weapon,
		"gold": calculate_duplicate_weapon_gold(normalized_id),
	}

func has_branch_options_for_fuse(weapon: Weapon, target_fuse: int) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	return not weapon.branch_runtime.get_available_branch_options_for_fuse(target_fuse).is_empty()

func find_equipped_weapon_by_id(weapon_id: String) -> Weapon:
	if _player == null:
		return null
	var normalized_id := str(weapon_id).strip_edges()
	if normalized_id == "":
		return null
	for equipped_weapon_ref in _player.PlayerData.player_weapon_list:
		var equipped_weapon := equipped_weapon_ref as Weapon
		if equipped_weapon == null or not is_instance_valid(equipped_weapon):
			continue
		if DataHandler.get_weapon_id_from_instance(equipped_weapon) == normalized_id:
			return equipped_weapon
	return null

func calculate_duplicate_weapon_gold(weapon_id: String) -> int:
	var weapon_def := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
	var base_price := 0
	if weapon_def != null:
		base_price = max(0, int(weapon_def.price))
	return _player._get_economy_config().get_duplicate_weapon_gold(base_price)

func notify_weapon_duplicate_result(existing_weapon: Weapon, weapon_id: String, result: Dictionary) -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("show_item_message"):
		return
	var resolved_id := str(weapon_id).strip_edges()
	var fallback_name := LocalizationManager.get_weapon_instance_display_name(existing_weapon)
	var weapon_name := LocalizationManager.get_weapon_name_by_id(resolved_id, fallback_name)
	var result_type := str(result.get("result", ""))
	if result_type != "fused" and result_type != "converted_to_gold":
		return
	var message := PREVIEW_FORMATTER.format_obtain_preview("", weapon_name, result)
	if message.strip_edges() == "":
		return
	ui.show_item_message(message, 1.8)

func refresh_weapon_related_ui() -> void:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if ui.has_method("update_inventory"):
		ui.update_inventory()
	if ui.upgrade_management_controller:
		ui.upgrade_management_controller.update_upg()
	if ui.has_method("refresh_border"):
		ui.refresh_border()

func try_prompt_branch_selection(weapon: Weapon, target_fuse: int = 0) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return
	if not ui.has_method("request_weapon_branch_selection"):
		return
	if target_fuse <= 0:
		target_fuse = int(weapon.fuse)
	ui.request_weapon_branch_selection(weapon, target_fuse)

func swap_weapon_position(weapon1, weapon2) -> void:
	if _player == null:
		return
	var player_data = _player.PlayerData
	if weapon1 == weapon2:
		return
	var slot1_index = player_data.player_weapon_list.find(weapon1)
	var slot2_index = player_data.player_weapon_list.find(weapon2)
	var temp = player_data.player_weapon_list[slot1_index]
	player_data.player_weapon_list[slot1_index] = player_data.player_weapon_list[slot2_index]
	player_data.player_weapon_list[slot2_index] = temp
	if player_data.main_weapon_index == slot1_index:
		player_data.main_weapon_index = slot2_index
	elif player_data.main_weapon_index == slot2_index:
		player_data.main_weapon_index = slot1_index
	player_data.on_select_weapon = player_data.main_weapon_index
	player_data.notify_weapon_list_changed()
	mark_weapon_structure_dirty(true)
	refresh_weapon_structure_if_needed()
	_player._rebuild_shared_heat_pool()

func refresh_weapon_structure_if_needed() -> void:
	if _player == null:
		return
	if not _weapon_list_dirty and not _weapon_roles_dirty and not _weapon_orbit_states_dirty:
		return
	var list_changed := false
	if _weapon_list_dirty:
		list_changed = sanitize_weapon_list()
		sync_tracked_weapon_exit_signals()
	if list_changed:
		_weapon_roles_dirty = true
		_weapon_orbit_states_dirty = true
	if _weapon_roles_dirty:
		apply_weapon_roles()
	if _weapon_orbit_states_dirty:
		_player._sync_weapon_orbit_states(_weapon_orbit_force_reset)
	_weapon_list_dirty = false
	_weapon_roles_dirty = false
	_weapon_orbit_states_dirty = false
	_weapon_orbit_force_reset = false

func sanitize_weapon_list() -> bool:
	var player_data = _player.PlayerData
	var valid_weapons: Array = []
	for weapon in player_data.player_weapon_list:
		if is_instance_valid(weapon):
			valid_weapons.append(weapon)
	var changed: bool = valid_weapons.size() != player_data.player_weapon_list.size()
	if changed:
		player_data.player_weapon_list = valid_weapons
	player_data.sanitize_main_weapon_index()
	if valid_weapons.size() == 1:
		player_data.main_weapon_index = 0
	return changed

func mark_weapon_structure_dirty(force_orbit_reset := false) -> void:
	_weapon_list_dirty = true
	_weapon_roles_dirty = true
	_weapon_orbit_states_dirty = true
	_weapon_orbit_force_reset = _weapon_orbit_force_reset or force_orbit_reset

func mark_weapon_roles_dirty() -> void:
	_weapon_roles_dirty = true
	_weapon_orbit_states_dirty = true

func connect_weapon_structure_signals() -> void:
	var player_data = _player.PlayerData
	if not player_data.weapon_list_changed.is_connected(Callable(_player, "_on_player_weapon_list_changed")):
		player_data.weapon_list_changed.connect(Callable(_player, "_on_player_weapon_list_changed"))
	if not player_data.main_weapon_index_changed.is_connected(Callable(_player, "_on_main_weapon_index_changed")):
		player_data.main_weapon_index_changed.connect(Callable(_player, "_on_main_weapon_index_changed"))

func disconnect_weapon_structure_signals() -> void:
	var player_data = _player.PlayerData
	if player_data != null and player_data.weapon_list_changed.is_connected(Callable(_player, "_on_player_weapon_list_changed")):
		player_data.weapon_list_changed.disconnect(Callable(_player, "_on_player_weapon_list_changed"))
	if player_data != null and player_data.main_weapon_index_changed.is_connected(Callable(_player, "_on_main_weapon_index_changed")):
		player_data.main_weapon_index_changed.disconnect(Callable(_player, "_on_main_weapon_index_changed"))

func sync_tracked_weapon_exit_signals() -> void:
	var active_ids: Dictionary = {}
	for weapon_ref in _player.PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		var instance_id := weapon.get_instance_id()
		active_ids[instance_id] = true
		if _tracked_weapon_exit_ids.has(instance_id):
			continue
		_tracked_weapon_exit_ids[instance_id] = true
		weapon.tree_exiting.connect(_player._on_tracked_weapon_tree_exiting.bind(instance_id), CONNECT_ONE_SHOT)
	for tracked_id in _tracked_weapon_exit_ids.keys():
		if not active_ids.has(tracked_id):
			_tracked_weapon_exit_ids.erase(tracked_id)

func on_tracked_weapon_tree_exiting(instance_id: int) -> void:
	_tracked_weapon_exit_ids.erase(instance_id)
	mark_weapon_structure_dirty(true)

func clear_tracked_weapon_exit_ids() -> void:
	_tracked_weapon_exit_ids.clear()

func apply_weapon_roles() -> void:
	for i in range(_player.PlayerData.player_weapon_list.size()):
		var weapon: Variant = _player.PlayerData.player_weapon_list[i]
		if weapon == null or not is_instance_valid(weapon):
			continue
		if weapon.has_method("set_weapon_role"):
			weapon.call("set_weapon_role", "main" if i == _player.PlayerData.main_weapon_index else "offhand")
	_player._debug_connect_weapon_passive_triggers()

func get_main_weapon() -> Weapon:
	if _player == null or _player.PlayerData == null:
		return null
	if _player.PlayerData.player_weapon_list.is_empty():
		return null
	_player.PlayerData.sanitize_main_weapon_index()
	var idx: int = int(_player.PlayerData.main_weapon_index)
	if idx < 0 or idx >= _player.PlayerData.player_weapon_list.size():
		return null
	var weapon: Variant = _player.PlayerData.player_weapon_list[idx]
	if weapon is Weapon:
		return weapon as Weapon
	return null

func get_offhand_weapons() -> Array:
	var result: Array = []
	for i in range(_player.PlayerData.player_weapon_list.size()):
		if i == _player.PlayerData.main_weapon_index:
			continue
		var weapon: Variant = _player.PlayerData.player_weapon_list[i]
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func can_switch_main_weapon() -> bool:
	return _player.PlayerData.can_switch_main_weapon()

func try_shift_main_weapon(step: int) -> bool:
	if not can_switch_main_weapon():
		return false
	var old_main := get_main_weapon()
	if not _player.PlayerData.shift_main_weapon(step):
		return false
	mark_weapon_roles_dirty()
	refresh_weapon_structure_if_needed()
	var new_main := get_main_weapon()
	_player._broadcast_weapon_passive_event(&"on_main_swapped", {
		"old_main": old_main,
		"new_main": new_main
	})
	return true
