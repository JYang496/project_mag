extends RefCounted
class_name WeaponSkillUnlockRuntime

var weapon: Weapon
var condition_id: StringName = StringName()
var condition_hint: String = ""
var required: float = 0.0
var progress: float = 0.0
var ready: bool = true
var _threshold_rearm_required: bool = false
var _attack_since_cast: bool = false


func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon


func configure(next_condition_id: StringName, next_hint: String, next_required: float) -> void:
	condition_id = next_condition_id
	condition_hint = next_hint
	required = maxf(next_required, 0.0)
	progress = 0.0
	ready = required <= 0.0
	_threshold_rearm_required = false
	_attack_since_cast = false


func update(delta: float) -> void:
	if weapon == null or not is_instance_valid(weapon) or ready or required <= 0.0:
		return
	match condition_id:
		&"support_time":
			if weapon.is_support_weapon():
				add_progress(maxf(delta, 0.0))
		&"weapon_attack_and_heat":
			if _attack_since_cast:
				_update_shared_heat_condition()
		&"shared_heat_hot":
			_update_shared_heat_condition()


func on_weapon_event(event: WeaponEvent) -> void:
	if event == null or ready or required <= 0.0:
		return
	match condition_id:
		&"primary_attack_count":
			if event.type == WeaponEvent.PRIMARY_ATTACK_FIRED:
				add_progress(1.0)
		&"weapon_attack_and_heat":
			if event.type == WeaponEvent.PRIMARY_ATTACK_FIRED:
				_attack_since_cast = true
				_update_shared_heat_condition()
		&"magazine_reload":
			if event.type == WeaponEvent.MAGAZINE_QUARTER_SPENT:
				progress = clampf(float(event.detail.get("spent_ratio", 0.0)), 0.0, required)
			elif event.type == WeaponEvent.RELOAD_STARTED:
				var spent_ratio := float(event.detail.get("spent_ratio", 0.0))
				if spent_ratio + 0.0001 >= required:
					mark_ready()
				else:
					progress = 0.0
		&"support_time":
			if event.type == WeaponEvent.WEAPON_ENTERED_SUPPORT:
				progress = 0.0
		&"weapon_kill":
			if event.type == WeaponEvent.TARGET_KILLED:
				mark_ready()


func set_progress(value: float) -> void:
	if ready or required <= 0.0:
		return
	progress = clampf(value, 0.0, required)
	if progress >= required - 0.0001:
		mark_ready()


func add_progress(amount: float) -> void:
	set_progress(progress + maxf(amount, 0.0))


func mark_ready() -> void:
	ready = true
	progress = required


func consume_ready() -> bool:
	if not ready:
		return false
	if required <= 0.0:
		return true
	ready = false
	progress = 0.0
	_threshold_rearm_required = condition_id == &"shared_heat_hot"
	_attack_since_cast = false
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("on_weapon_skill_unlock_consumed"):
		weapon.call("on_weapon_skill_unlock_consumed", condition_id)
	return true


func force_ready() -> void:
	mark_ready()


func reset() -> void:
	progress = 0.0
	ready = required <= 0.0
	_threshold_rearm_required = false
	_attack_since_cast = false


func get_status() -> Dictionary:
	var ratio := 1.0 if required <= 0.0 else clampf(progress / required, 0.0, 1.0)
	return {
		"condition_id": str(condition_id),
		"condition_group": str(get_condition_group()),
		"condition_hint": condition_hint,
		"unlock_required": required,
		"unlock_current": progress,
		"unlock_progress": ratio,
		"unlock_ready": ready,
		"unlock_state": "ready" if ready else "locked",
		"ready_persists_until_cast": true,
	}


func get_condition_group() -> StringName:
	if condition_id in [&"magazine_reload", &"support_time", &"weapon_kill", &"primary_attack_count"]:
		return &"combat_cycle"
	if condition_id in [&"wall_bounce", &"long_dash_hit", &"support_to_main_close_hit", &"far_hit"]:
		return &"positioning_action"
	if condition_id in [&"magazine_distinct_targets", &"projectile_distinct_targets", &"explosion_distinct_targets", &"freeze_buildup"]:
		return &"multi_target_accumulation"
	if condition_id in [&"shared_heat_hot", &"weapon_attack_and_heat"]:
		return &"shared_resource"
	if condition_id == &"player_damaged":
		return &"reactive"
	return &"unconfigured"


func clear_for_weapon_exit() -> void:
	weapon = null
	condition_id = StringName()
	condition_hint = ""
	required = 0.0
	progress = 0.0
	ready = false
	_threshold_rearm_required = false
	_attack_since_cast = false


func _update_shared_heat_condition() -> void:
	var heat_ratio := _read_hot_heat_ratio()
	progress = minf(heat_ratio, required)
	if _threshold_rearm_required:
		if heat_ratio + 0.0001 < required:
			_threshold_rearm_required = false
		return
	if heat_ratio + 0.0001 >= required:
		mark_ready()


func _read_hot_heat_ratio() -> float:
	var player := _resolve_player()
	if player == null:
		return 0.0
	if player.has_method("get_signed_heat_ratio"):
		return maxf(float(player.call("get_signed_heat_ratio")), 0.0)
	if player.has_method("get_total_heat_ratio"):
		return clampf(float(player.call("get_total_heat_ratio")), 0.0, 1.0)
	return 0.0


func _resolve_player() -> Node:
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		return PlayerData.player
	if weapon != null and is_instance_valid(weapon):
		return DamageManager.resolve_source_player(weapon)
	return null
