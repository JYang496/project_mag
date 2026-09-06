extends RefCounted
class_name PlayerWeaponCommandController

const SLOT_ACTIONS: Array[StringName] = [
	&"WEAPON_SLOT_1",
	&"WEAPON_SLOT_2",
	&"WEAPON_SLOT_3",
	&"WEAPON_SLOT_4",
]
var _player


func setup(player) -> void:
	_player = player


func process_input_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.echo:
		return false
	if not _can_accept_combat_command():
		clear()
		return false
	if event.is_action_pressed("SWITCH_LEFT"):
		return bool(_player.try_shift_main_weapon(-1))
	if event.is_action_pressed("SWITCH_RIGHT"):
		return bool(_player.try_shift_main_weapon(1))
	if event.is_action_pressed("WEAPON_SKILL"):
		_player.request_weapon_skill_at_slot(int(_player.PlayerData.main_weapon_index))
		return true
	for slot_index in range(SLOT_ACTIONS.size()):
		var action := SLOT_ACTIONS[slot_index]
		if event.is_action_pressed(action):
			_player.try_select_main_weapon(slot_index)
			_player.request_weapon_skill_at_slot(slot_index)
			return true
	return false


func process(_delta: float) -> void:
	if not _can_accept_combat_command():
		clear()


func clear() -> void:
	pass


func ensure_input_actions() -> void:
	var keycodes: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for slot_index in range(SLOT_ACTIONS.size()):
		var action := SLOT_ACTIONS[slot_index]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var input_event := InputEventKey.new()
			input_event.physical_keycode = keycodes[slot_index]
			InputMap.action_add_event(action, input_event)


func _can_accept_combat_command() -> bool:
	if _player == null or not is_instance_valid(_player) or _player.get_tree() == null:
		return false
	if _player.get_tree().paused:
		return false
	return PhaseManager.current_state() == PhaseManager.BATTLE
