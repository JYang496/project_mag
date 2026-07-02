extends RefCounted
class_name PlayerActiveSkillRuntime

const SKILL_ENERGY_STATE_SCRIPT := preload("res://Player/Mechas/scripts/skill_energy_state.gd")
const PLAYER_SKILL_CONTROLLER_SCRIPT := preload("res://Player/Mechas/scripts/player_skill_controller.gd")
const WEAPON_ACTION_CONTROLLER_SCRIPT := preload("res://Player/Mechas/scripts/weapon_action_controller.gd")

var _player
var _reload_block_hint_ready_at_msec: int = 0
var _energy_state: RefCounted
var _player_skill_controller: RefCounted
var _weapon_action_controller: RefCounted

func setup(player) -> void:
	_player = player
	_ensure_controllers()
	_energy_state.setup(player)
	_player_skill_controller.setup(player)
	_weapon_action_controller.setup(player)

func reset_energy_to_max() -> void:
	_ensure_controllers()
	_energy_state.reset_to_max()

func process_input_event(event: InputEvent) -> void:
	if event.is_action_pressed("SKILL_PLAYER"):
		try_cast_player_active_skill()
	if event.is_action_pressed("SKILL_WEAPON"):
		try_reload_main_weapon()

func setup_default_active_skill() -> void:
	_ensure_controllers()
	_player_skill_controller.setup_default_active_skill()

func try_cast_player_active_skill() -> void:
	_ensure_controllers()
	_player_skill_controller.try_cast_player_active_skill()

func try_cast_main_weapon_active_skill() -> void:
	_ensure_controllers()
	_weapon_action_controller.try_cast_main_weapon_active_skill()

func try_reload_main_weapon() -> void:
	_ensure_controllers()
	_weapon_action_controller.try_reload_main_weapon()

func try_show_reload_block_hint(main_weapon: Weapon) -> void:
	_ensure_controllers()
	_weapon_action_controller.set_reload_block_hint_ready_at_msec(_reload_block_hint_ready_at_msec)
	_weapon_action_controller.try_show_reload_block_hint(main_weapon)
	_reload_block_hint_ready_at_msec = _weapon_action_controller.get_reload_block_hint_ready_at_msec()

func ensure_input_actions() -> void:
	_ensure_input_action("SKILL_PLAYER", [KEY_SPACE])
	_ensure_input_action("SKILL_WEAPON", [KEY_R])

func get_current_energy() -> float:
	_ensure_controllers()
	return _energy_state.get_current_energy()

func get_max_energy() -> float:
	_ensure_controllers()
	return _energy_state.get_max_energy()

func get_active_skill_energy_cost() -> float:
	_ensure_controllers()
	return _energy_state.get_active_skill_energy_cost()

func consume_energy(amount: float) -> bool:
	_ensure_controllers()
	return _energy_state.consume_energy(amount)

func add_energy(amount: float) -> void:
	_ensure_controllers()
	_energy_state.add_energy(amount)

func regen_energy(delta: float) -> void:
	_ensure_controllers()
	_energy_state.regen_energy(delta)

func get_last_weapon_skill_fail_reason() -> String:
	_ensure_controllers()
	return _weapon_action_controller.get_last_weapon_skill_fail_reason()

func get_weapon_active_cd_remaining() -> float:
	_ensure_controllers()
	return _weapon_action_controller.get_weapon_active_cd_remaining()

func get_weapon_active_cd_ratio() -> float:
	_ensure_controllers()
	return _weapon_action_controller.get_weapon_active_cd_ratio()

func _ensure_controllers() -> void:
	if _energy_state == null:
		_energy_state = SKILL_ENERGY_STATE_SCRIPT.new()
	if _player_skill_controller == null:
		_player_skill_controller = PLAYER_SKILL_CONTROLLER_SCRIPT.new()
	if _weapon_action_controller == null:
		_weapon_action_controller = WEAPON_ACTION_CONTROLLER_SCRIPT.new()
	if _player != null:
		_energy_state.setup(_player)
		_player_skill_controller.setup(_player)
		_weapon_action_controller.setup(_player)

func _ensure_input_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if InputMap.action_get_events(action_name).is_empty():
		for keycode in keycodes:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action_name, ev)
