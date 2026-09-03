extends RefCounted
class_name WeaponFireController

var weapon: Weapon
var _external_attack_speed_mul_modifiers: Dictionary = {}

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func setup_timer() -> void:
	if weapon == null:
		return
	weapon.cooldown_timer = weapon.get_node_or_null("CooldownTimer") as Timer

func on_cooldown_timer_timeout() -> void:
	if weapon == null:
		return
	weapon.is_on_cooldown = false

func request_primary_fire() -> bool:
	if weapon == null:
		return false
	if not weapon.is_attack_phase_allowed():
		return false
	if weapon.is_on_cooldown:
		return false
	if not weapon.can_fire_with_heat():
		return false
	if not weapon.can_fire_with_ammo():
		_request_reload_when_empty()
		return false
	var ammo_cost := maxi(weapon.get_primary_fire_ammo_cost(), 1)
	if weapon.current_ammo < ammo_cost:
		weapon.request_reload()
		return false
	if not weapon.consume_ammo(ammo_cost):
		_request_reload_when_empty()
		return false
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer:
		cooldown_timer.wait_time = maxf(weapon.get_runtime_attack_cooldown(), 0.01)
	weapon.prepare_energy_release_attack()
	weapon.shoot.emit()
	weapon.finish_energy_release_attack()
	weapon.play_fire_feedback()
	weapon.notify_main_weapon_fired()
	weapon.register_shot_heat()
	_request_reload_when_empty()
	return true

func set_external_attack_speed_multiplier(multiplier: float) -> void:
	if weapon == null:
		return
	var source_id := StringName("ranger_attack_speed_%s" % str(weapon.get_instance_id()))
	if is_equal_approx(multiplier, 1.0):
		remove_external_attack_speed_mul(source_id)
	else:
		apply_external_attack_speed_mul(source_id, multiplier)

func apply_external_attack_speed_mul(source_id: StringName, multiplier: float) -> void:
	if source_id == StringName():
		return
	var clamped_mul := clampf(multiplier, 0.1, 10.0)
	if is_equal_approx(clamped_mul, 1.0):
		remove_external_attack_speed_mul(source_id)
		return
	var previous_mul := float(_external_attack_speed_mul_modifiers.get(source_id, 1.0))
	if _external_attack_speed_mul_modifiers.has(source_id) and is_equal_approx(previous_mul, clamped_mul):
		return
	_external_attack_speed_mul_modifiers[source_id] = clamped_mul
	_notify_attack_speed_status(source_id, clamped_mul, true)

func remove_external_attack_speed_mul(source_id: StringName) -> void:
	if not _external_attack_speed_mul_modifiers.has(source_id):
		return
	var previous_mul := float(_external_attack_speed_mul_modifiers.get(source_id, 1.0))
	_external_attack_speed_mul_modifiers.erase(source_id)
	_notify_attack_speed_status(source_id, previous_mul, false)

func get_external_attack_speed_multiplier() -> float:
	var total := 1.0
	for mul in _external_attack_speed_mul_modifiers.values():
		total *= float(mul)
	return clampf(total, 0.1, 10.0)

func get_effective_cooldown(base_cooldown: float) -> float:
	var speed_mul := maxf(get_external_attack_speed_multiplier() * _get_cold_attack_speed_multiplier(), 0.1)
	return maxf(base_cooldown / speed_mul, 0.01)

func _get_cold_attack_speed_multiplier() -> float:
	var player := PlayerData.player as Player
	if player == null or not is_instance_valid(player):
		return 1.0
	return maxf(player.get_cold_attack_speed_multiplier(), 0.1)

func start_weapon_cooldown(min_cooldown: float = 0.01) -> void:
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer == null:
		setup_timer()
		cooldown_timer = get_cooldown_timer()
	if cooldown_timer == null:
		return
	cooldown_timer.wait_time = maxf(weapon.get_runtime_attack_cooldown(), min_cooldown)
	cooldown_timer.start()

func sync_cooldown_timer() -> void:
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer == null:
		setup_timer()
		cooldown_timer = get_cooldown_timer()
	if cooldown_timer != null:
		cooldown_timer.wait_time = weapon.get_runtime_attack_cooldown()

func get_cooldown_timer() -> Timer:
	if weapon == null:
		return null
	return weapon.cooldown_timer

func _request_reload_when_empty() -> void:
	if weapon == null:
		return
	if weapon.uses_ammo_system() and weapon.current_ammo <= 0:
		weapon.request_reload()

func _notify_attack_speed_status(source_id: StringName, multiplier: float, active: bool) -> void:
	var player := PlayerData.player as Player
	if player != null and is_instance_valid(player):
		player.notify_weapon_status_change(
			&"attack_speed_up" if multiplier > 1.0 else &"attack_speed_down",
			source_id,
			active
		)
