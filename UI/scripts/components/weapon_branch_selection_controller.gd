extends RefCounted
class_name WeaponBranchSelectionController

var owner_ui: UI
var queue: Array[Dictionary] = []

func bind(ui: UI) -> void:
	owner_ui = ui
	sync_state_from_owner()

func request_weapon_branch_selection(weapon: Weapon, target_fuse: int = 0) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if owner_ui == null:
		return false
	owner_ui._init_branch_select_panel()
	if owner_ui.branch_select_panel == null or not is_instance_valid(owner_ui.branch_select_panel):
		return false
	var resolved_target_fuse := target_fuse if target_fuse > 0 else int(weapon.fuse)
	queue.append({
		"weapon": weakref(weapon),
		"weapon_id": DataHandler.get_weapon_id_from_instance(weapon),
		"target_fuse": resolved_target_fuse,
	})
	_sync_public_fields_to_owner()
	request_next()
	return true

func has_pending_selection() -> bool:
	if owner_ui == null:
		return not queue.is_empty()
	return not queue.is_empty() \
		or (owner_ui.branch_select_panel != null and is_instance_valid(owner_ui.branch_select_panel) and owner_ui.branch_select_panel.visible)

func is_blocking_interactions() -> bool:
	return has_pending_selection()

func request_next() -> void:
	if owner_ui == null:
		return
	if owner_ui.branch_select_panel == null or not is_instance_valid(owner_ui.branch_select_panel):
		queue.clear()
		_sync_public_fields_to_owner()
		return
	if owner_ui.branch_select_panel.visible:
		return
	if TaskRewardManager.is_reward_blocking_interactions():
		return
	if not _is_safe_state():
		return
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		if _open_entry(entry):
			_sync_public_fields_to_owner()
			return
	_sync_public_fields_to_owner()

func on_branch_selected(weapon: Weapon, branch_id: String) -> void:
	if owner_ui == null:
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.branch_runtime.set_branch(branch_id):
		push_warning("Failed to apply branch '%s' for weapon '%s'." % [branch_id, weapon.name])
	owner_ui.call_deferred("_finalize_branch_selected_weapon", weapon)

func finalize_branch_selected_weapon(weapon: Weapon) -> void:
	if owner_ui == null:
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var is_already_owned := PlayerData.player_weapon_list.has(weapon)
	if not is_already_owned:
		PlayerData.player.create_weapon(weapon)
	owner_ui.upgrade_management_controller.update_upg()
	owner_ui.refresh_border()
	request_next()

func sync_state_from_owner() -> void:
	if owner_ui == null:
		return
	queue = owner_ui._branch_selection_queue

func _is_safe_state() -> bool:
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		return false
	if PhaseManager.current_state() == PhaseManager.GAMEOVER:
		return false
	return true

func _warn_skipped(weapon_id: String, target_fuse: int, reason: String) -> void:
	push_warning("Skipped branch selection for weapon id=%s fuse=%d: %s" % [weapon_id, target_fuse, reason])
	if owner_ui == null:
		return
	var message := ""
	if reason == "no_options":
		message = LocalizationManager.tr_key("ui.branch.no_options", "No evolution branch is configured for this weapon.")
	elif reason == "missing_weapon":
		message = LocalizationManager.tr_key("ui.branch.missing_weapon", "Evolution choice skipped because the weapon is no longer available.")
	if message != "":
		owner_ui.show_item_message(message, 2.0)

func _open_entry(entry: Dictionary) -> bool:
	var weapon_ref: WeakRef = entry.get("weapon", null)
	var queued_weapon := weapon_ref.get_ref() as Weapon if weapon_ref else null
	var weapon_id := str(entry.get("weapon_id", ""))
	var target_fuse := int(entry.get("target_fuse", 0))
	if queued_weapon == null or not is_instance_valid(queued_weapon):
		_warn_skipped(weapon_id, target_fuse, "missing_weapon")
		return false
	var branch_options := queued_weapon.branch_runtime.get_branch_options()
	if branch_options.is_empty():
		_warn_skipped(weapon_id, target_fuse, "no_options")
		return false
	owner_ui.branch_select_panel.open_for_weapon(queued_weapon, branch_options)
	return true

func _sync_public_fields_to_owner() -> void:
	if owner_ui == null:
		return
	owner_ui._branch_selection_queue = queue
