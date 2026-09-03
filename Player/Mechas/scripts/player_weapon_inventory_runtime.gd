extends RefCounted
class_name PlayerWeaponInventoryRuntime


var _player
var _weapon_list_dirty := true
var _weapon_roles_dirty := true
var _weapon_orbit_states_dirty := true
var _weapon_orbit_force_reset := true
var _tracked_weapon_exit_ids: Dictionary = {}

func setup(player) -> void:
	_player = player

func create_weapon(item_id, level := 1, convert_duplicate := false) -> void:
	if _player == null:
		return
	var player_data = _player.PlayerData
	var weapon: Weapon
	var incoming_weapon_id := ""
	if item_id is String:
		incoming_weapon_id = str(item_id).strip_edges()
		if convert_duplicate or find_equipped_weapon_by_id(incoming_weapon_id) != null:
			var conversion_result := try_weapon_obtain_conversion(incoming_weapon_id)
			var result_type := str(conversion_result.get("result", "not_applicable"))
			if result_type == "dismantled_to_core":
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
		if incoming_weapon_id != "" and find_equipped_weapon_by_id(incoming_weapon_id) != null:
			var duplicate_result := try_weapon_obtain_conversion(incoming_weapon_id)
			var duplicate_type := str(duplicate_result.get("result", "not_applicable"))
			if duplicate_type == "dismantled_to_core":
				weapon.queue_free()
				return

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

func try_weapon_obtain_conversion(weapon_id: String) -> Dictionary:
	if _player == null:
		return {"result": "invalid", "weapon_id": weapon_id}
	var player_data = _player.PlayerData
	var prediction := predict_weapon_obtain(weapon_id)
	var result_type := str(prediction.get("result", "not_applicable"))
	if result_type == "not_applicable" or result_type == "invalid":
		return prediction
	var subject := prediction.get("weapon", null) as Weapon
	if subject == null or not is_instance_valid(subject):
		return {"result": "invalid", "weapon_id": weapon_id}
	if result_type == "dismantled_to_core":
		var dismantled := InventoryData.dismantle_duplicate_weapon(weapon_id, subject)
		refresh_weapon_related_ui()
		return dismantled
	refresh_weapon_related_ui()
	return prediction

func predict_weapon_obtain(weapon_id: String) -> Dictionary:
	var normalized_id := str(weapon_id).strip_edges()
	if normalized_id == "":
		return {"result": "invalid", "weapon_id": normalized_id}
	var equipped_weapon := find_equipped_weapon_by_id(normalized_id)
	if equipped_weapon == null:
		return {"result": "not_applicable", "weapon_id": normalized_id}
	var preview := InventoryData.build_duplicate_weapon_core_preview(normalized_id)
	preview["weapon"] = equipped_weapon
	return preview

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
		var weapon := _player.PlayerData.player_weapon_list[i] as Weapon
		if weapon == null:
			continue
		weapon.set_weapon_role("main" if i == _player.PlayerData.main_weapon_index else "support")
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

func get_support_weapons() -> Array:
	var result: Array = []
	for i in range(_player.PlayerData.player_weapon_list.size()):
		if i == _player.PlayerData.main_weapon_index:
			continue
		var weapon: Variant = _player.PlayerData.player_weapon_list[i]
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func get_all_weapons() -> Array:
	var result: Array = []
	for weapon_variant in _player.PlayerData.player_weapon_list:
		var weapon := weapon_variant as Weapon
		if weapon != null and is_instance_valid(weapon):
			result.append(weapon)
	return result

func get_weapon_at_slot(slot_index: int) -> Weapon:
	if _player == null or _player.PlayerData == null:
		return null
	if slot_index < 0 or slot_index >= _player.PlayerData.player_weapon_list.size():
		return null
	var weapon := _player.PlayerData.player_weapon_list[slot_index] as Weapon
	return weapon if weapon != null and is_instance_valid(weapon) else null

func try_select_main_weapon(slot_index: int) -> bool:
	sanitize_weapon_list()
	var weapon := get_weapon_at_slot(slot_index)
	if weapon == null or slot_index == int(_player.PlayerData.main_weapon_index):
		return false
	_player.PlayerData.set_main_weapon_index(slot_index)
	mark_weapon_roles_dirty()
	refresh_weapon_structure_if_needed()
	return int(_player.PlayerData.main_weapon_index) == slot_index

func request_weapon_skill_at_slot(slot_index: int) -> bool:
	var weapon := get_weapon_at_slot(slot_index)
	if weapon == null:
		return false
	return bool(weapon.request_weapon_skill())

func can_switch_main_weapon() -> bool:
	return _player.PlayerData.can_switch_main_weapon()

func try_shift_main_weapon(step: int) -> bool:
	if not can_switch_main_weapon():
		return false
	if not _player.PlayerData.shift_main_weapon(step):
		return false
	mark_weapon_roles_dirty()
	refresh_weapon_structure_if_needed()
	return true
