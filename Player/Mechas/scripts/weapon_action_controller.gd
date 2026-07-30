extends RefCounted
class_name WeaponActionController

var _player
var _reload_block_hint_ready_at_msec: int = 0

func setup(player) -> void:
	_player = player

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
	var hint_text := "Reloading"
	if LocalizationManager and LocalizationManager.has_method("tr_key"):
		hint_text = LocalizationManager.tr_key("ui.hud.reloading_now", "Reloading")
	if _player.has_method("_spawn_keyed_player_floating_hint"):
		_player.call("_spawn_keyed_player_floating_hint", hint_text, &"reload_blocked", _player.reload_block_hint_interval_sec)
	if GlobalVariables.ui != null and is_instance_valid(GlobalVariables.ui) \
			and GlobalVariables.ui.has_method("show_controls_context_reminder"):
		GlobalVariables.ui.call("show_controls_context_reminder", &"RELOAD", hint_text)

func set_reload_block_hint_ready_at_msec(value: int) -> void:
	_reload_block_hint_ready_at_msec = value

func get_reload_block_hint_ready_at_msec() -> int:
	return _reload_block_hint_ready_at_msec
