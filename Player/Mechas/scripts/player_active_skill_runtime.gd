extends RefCounted
class_name PlayerActiveSkillRuntime

var _player
var _player_energy: float = 100.0
var _last_weapon_skill_fail_reason: String = ""
var _last_player_skill_fail_reason: String = ""
var _reload_block_hint_ready_at_msec: int = 0

func setup(player) -> void:
	_player = player

func reset_energy_to_max() -> void:
	_player_energy = get_max_energy()

func process_input_event(event: InputEvent) -> void:
	if event.is_action_pressed("SKILL_PLAYER"):
		try_cast_player_active_skill()
	if event.is_action_pressed("SKILL_WEAPON"):
		try_reload_main_weapon()

func setup_default_active_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.active_skill_holder == null:
		push_warning("ActiveSkill node is missing, default active skill will not be loaded.")
		return
	if _player.active_skill_holder.get_child_count() > 0:
		return
	var scene_path := str(_player.default_active_skill_path)
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	var scene_resource := load(scene_path)
	var skill_scene := scene_resource as PackedScene
	if skill_scene == null:
		push_warning("Failed to load default active skill scene: %s" % scene_path)
		return
	var skill_instance := skill_scene.instantiate()
	if not (skill_instance is Skills):
		push_warning("Default active skill must inherit Skills: %s" % scene_path)
		return
	_player.active_skill_holder.add_child(skill_instance)

func try_cast_player_active_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.player_active_skill.emit()
	_player.active_skill.emit()
	_last_player_skill_fail_reason = ""

func try_cast_main_weapon_active_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var main_weapon: Weapon = _player.get_main_weapon()
	if main_weapon == null:
		_last_weapon_skill_fail_reason = "no_main_weapon"
		return
	if not main_weapon.has_method("request_weapon_active"):
		_last_weapon_skill_fail_reason = "unsupported"
		return
	var result_variant: Variant = main_weapon.call("request_weapon_active")
	if result_variant is Dictionary:
		var result := result_variant as Dictionary
		if bool(result.get("ok", false)):
			_player.weapon_active_skill.emit()
			_last_weapon_skill_fail_reason = ""
		else:
			_last_weapon_skill_fail_reason = str(result.get("reason", "condition"))
			if _player.has_method("_broadcast_weapon_passive_event"):
				_player.call("_broadcast_weapon_passive_event", &"on_main_active_cast_failed", {
					"reason": _last_weapon_skill_fail_reason
				})
	else:
		_last_weapon_skill_fail_reason = "condition"

func try_reload_main_weapon() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if PhaseManager != null and PhaseManager.has_method("current_state"):
		if str(PhaseManager.current_state()) != str(PhaseManager.BATTLE):
			return
	var main_weapon: Weapon = _player.get_main_weapon()
	if main_weapon == null:
		return
	if not main_weapon.has_method("request_reload"):
		return
	var reload_started := bool(main_weapon.call("request_reload"))
	if not reload_started:
		return
	if _player.has_method("_ensure_assist_system"):
		_player.call("_ensure_assist_system")
	if _player._assist_system != null:
		_player._assist_system.handle_post_fire(main_weapon, true)

func try_show_reload_block_hint(main_weapon: Weapon) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	if not main_weapon.has_method("uses_ammo_system") or not bool(main_weapon.call("uses_ammo_system")):
		return
	var reloading_variant: Variant = main_weapon.get("is_reloading")
	if reloading_variant == null or not bool(reloading_variant):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < _reload_block_hint_ready_at_msec:
		return
	_reload_block_hint_ready_at_msec = now_msec + int(maxf(float(_player.reload_block_hint_interval_sec), 0.05) * 1000.0)
	var hint_text := "正在换弹中"
	if LocalizationManager and LocalizationManager.has_method("tr_key"):
		hint_text = LocalizationManager.tr_key("ui.hud.reloading_now", "正在换弹中")
	if _player.has_method("_spawn_keyed_player_floating_hint"):
		_player.call("_spawn_keyed_player_floating_hint", hint_text, &"reload_blocked", _player.reload_block_hint_interval_sec)
	if GlobalVariables.ui != null and is_instance_valid(GlobalVariables.ui) \
			and GlobalVariables.ui.has_method("show_controls_context_reminder"):
		GlobalVariables.ui.call("show_controls_context_reminder", &"SKILL_WEAPON", hint_text)

func ensure_input_actions() -> void:
	_ensure_input_action("SKILL_PLAYER", [KEY_SPACE])
	_ensure_input_action("SKILL_WEAPON", [KEY_R])

func get_current_energy() -> float:
	return _player_energy

func get_max_energy() -> float:
	if _player == null or not is_instance_valid(_player):
		return 1.0
	return maxf(float(_player.player_max_energy), 1.0)

func get_active_skill_energy_cost() -> float:
	var skill := _get_first_active_skill()
	if skill == null:
		return 0.0
	if skill.has_method("get_energy_cost"):
		return maxf(float(skill.call("get_energy_cost")), 0.0)
	return maxf(float(skill.get("energy_cost")), 0.0)

func consume_energy(amount: float) -> bool:
	var required := maxf(amount, 0.0)
	if _player_energy < required:
		return false
	_player_energy -= required
	return true

func add_energy(amount: float) -> void:
	_player_energy = clampf(_player_energy + maxf(amount, 0.0), 0.0, get_max_energy())

func regen_energy(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if float(_player.player_energy_regen_per_sec) <= 0.0:
		return
	add_energy(float(_player.player_energy_regen_per_sec) * maxf(delta, 0.0))

func get_last_weapon_skill_fail_reason() -> String:
	return _last_weapon_skill_fail_reason

func get_weapon_active_cd_remaining() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var weapon: Weapon = _player.get_main_weapon()
	if weapon == null:
		return 0.0
	if not weapon.has_method("get_weapon_active_cd_remaining"):
		return 0.0
	return float(weapon.call("get_weapon_active_cd_remaining"))

func get_weapon_active_cd_ratio() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var weapon: Weapon = _player.get_main_weapon()
	if weapon == null:
		return 0.0
	if not weapon.has_method("get_weapon_active_cd_ratio"):
		return 0.0
	return float(weapon.call("get_weapon_active_cd_ratio"))

func _get_first_active_skill() -> Skills:
	if _player == null or not is_instance_valid(_player):
		return null
	if _player.active_skill_holder == null or not is_instance_valid(_player.active_skill_holder):
		return null
	for child in _player.active_skill_holder.get_children():
		if child is Skills:
			return child as Skills
	return null

func _ensure_input_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if InputMap.action_get_events(action_name).is_empty():
		for keycode in keycodes:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action_name, ev)
