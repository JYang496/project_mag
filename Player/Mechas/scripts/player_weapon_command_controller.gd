extends RefCounted
class_name PlayerWeaponCommandController

const SLOT_ACTIONS: Array[StringName] = [
	&"WEAPON_SLOT_1",
	&"WEAPON_SLOT_2",
	&"WEAPON_SLOT_3",
	&"WEAPON_SLOT_4",
]
const SKILL_HOLD_THRESHOLD_SEC: float = 0.28

var _player
var _pressed_at_msec: Dictionary = {}
var _hold_threshold_reached: Dictionary = {}
var _skill_cast_consumed: Dictionary = {}
var _main_skill_pressed_at_msec: int = -1
var _main_skill_slot: int = -1
var _main_skill_threshold_reached: bool = false
var _main_skill_cast_consumed: bool = false


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
		_main_skill_pressed_at_msec = Time.get_ticks_msec()
		_main_skill_slot = int(_player.PlayerData.main_weapon_index)
		_main_skill_threshold_reached = false
		_main_skill_cast_consumed = false
		return true
	if event.is_action_released("WEAPON_SKILL") and _main_skill_pressed_at_msec >= 0:
		_clear_main_skill_hold()
		return true
	for slot_index in range(SLOT_ACTIONS.size()):
		var action := SLOT_ACTIONS[slot_index]
		if event.is_action_pressed(action):
			_pressed_at_msec[slot_index] = Time.get_ticks_msec()
			_hold_threshold_reached[slot_index] = false
			_skill_cast_consumed[slot_index] = false
			return true
		if event.is_action_released(action) and _pressed_at_msec.has(slot_index):
			var held_sec := float(Time.get_ticks_msec() - int(_pressed_at_msec[slot_index])) / 1000.0
			var reached_threshold := bool(_hold_threshold_reached.get(slot_index, false)) \
				or held_sec >= SKILL_HOLD_THRESHOLD_SEC
			_pressed_at_msec.erase(slot_index)
			_hold_threshold_reached.erase(slot_index)
			_skill_cast_consumed.erase(slot_index)
			if not reached_threshold:
				_player.try_select_main_weapon(slot_index)
			return true
	return false


func process(_delta: float) -> void:
	if not _can_accept_combat_command():
		clear()
		return
	var now_msec := Time.get_ticks_msec()
	for slot_variant in _pressed_at_msec.keys():
		var slot_index := int(slot_variant)
		if bool(_skill_cast_consumed.get(slot_index, false)):
			continue
		var held_sec := float(now_msec - int(_pressed_at_msec[slot_index])) / 1000.0
		if held_sec < SKILL_HOLD_THRESHOLD_SEC:
			continue
		_hold_threshold_reached[slot_index] = true
		if bool(_player.request_weapon_skill_at_slot(slot_index)):
			_skill_cast_consumed[slot_index] = true
	_process_main_skill_hold(now_msec)


func get_hold_progress(slot_index: int) -> float:
	var progress := 0.0
	if _pressed_at_msec.has(slot_index) and not bool(_skill_cast_consumed.get(slot_index, false)):
		var elapsed_sec := float(Time.get_ticks_msec() - int(_pressed_at_msec[slot_index])) / 1000.0
		progress = clampf(elapsed_sec / SKILL_HOLD_THRESHOLD_SEC, 0.0, 1.0)
	if _main_skill_slot == slot_index and _main_skill_pressed_at_msec >= 0 \
			and not _main_skill_cast_consumed:
		var main_elapsed_sec := float(Time.get_ticks_msec() - _main_skill_pressed_at_msec) / 1000.0
		progress = maxf(progress, clampf(main_elapsed_sec / SKILL_HOLD_THRESHOLD_SEC, 0.0, 1.0))
	return progress


func clear() -> void:
	_pressed_at_msec.clear()
	_hold_threshold_reached.clear()
	_skill_cast_consumed.clear()
	_clear_main_skill_hold()


func _process_main_skill_hold(now_msec: int) -> void:
	if _main_skill_pressed_at_msec < 0 or _main_skill_cast_consumed:
		return
	var held_sec := float(now_msec - _main_skill_pressed_at_msec) / 1000.0
	if held_sec < SKILL_HOLD_THRESHOLD_SEC:
		return
	_main_skill_threshold_reached = true
	if bool(_player.request_weapon_skill_at_slot(_main_skill_slot)):
		_main_skill_cast_consumed = true


func _clear_main_skill_hold() -> void:
	_main_skill_pressed_at_msec = -1
	_main_skill_slot = -1
	_main_skill_threshold_reached = false
	_main_skill_cast_consumed = false


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
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return true
	return str(PhaseManager.current_state()) == str(PhaseManager.BATTLE)
