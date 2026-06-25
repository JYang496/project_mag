extends RefCounted
class_name WeaponFireController

var weapon: Node
var _external_attack_speed_mul_modifiers: Dictionary = {}

func setup(source_weapon: Node) -> void:
	weapon = source_weapon

func setup_timer() -> void:
	if weapon == null:
		return
	weapon.set("cooldown_timer", weapon.get_node_or_null("CooldownTimer"))

func on_cooldown_timer_timeout() -> void:
	if weapon == null:
		return
	weapon.set("is_on_cooldown", false)

func request_primary_fire() -> bool:
	if weapon == null:
		return false
	if weapon.has_method("is_attack_phase_allowed") and not bool(weapon.call("is_attack_phase_allowed")):
		return false
	if bool(weapon.get("is_on_cooldown")):
		return false
	if weapon.has_method("can_fire_with_heat") and not bool(weapon.call("can_fire_with_heat")):
		return false
	if weapon.has_method("can_fire_with_ammo") and not bool(weapon.call("can_fire_with_ammo")):
		_request_reload_when_empty()
		return false
	if weapon.has_method("consume_ammo") and not bool(weapon.call("consume_ammo", 1)):
		_request_reload_when_empty()
		return false
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer:
		cooldown_timer.wait_time = maxf(get_effective_cooldown(float(weapon.get("attack_cooldown"))), 0.01)
	weapon.emit_signal("shoot")
	if weapon.has_method("play_fire_feedback"):
		weapon.call("play_fire_feedback")
	if weapon.has_method("notify_main_weapon_fired"):
		weapon.call("notify_main_weapon_fired")
	if weapon.has_method("register_shot_heat"):
		weapon.call("register_shot_heat")
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
	var speed_mul := maxf(get_external_attack_speed_multiplier(), 0.1)
	return maxf(base_cooldown / speed_mul, 0.01)

func start_weapon_cooldown(base_cooldown: float, min_cooldown: float = 0.01) -> void:
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer == null:
		setup_timer()
		cooldown_timer = get_cooldown_timer()
	if cooldown_timer == null:
		return
	cooldown_timer.wait_time = maxf(get_effective_cooldown(base_cooldown), min_cooldown)
	cooldown_timer.start()

func sync_cooldown_timer() -> void:
	var cooldown_timer := get_cooldown_timer()
	if cooldown_timer == null:
		setup_timer()
		cooldown_timer = get_cooldown_timer()
	if cooldown_timer != null and float(weapon.get("attack_cooldown")) > 0.0:
		cooldown_timer.wait_time = float(weapon.get("attack_cooldown"))

func get_cooldown_timer() -> Timer:
	if weapon == null:
		return null
	var timer_variant: Variant = weapon.get("cooldown_timer")
	if timer_variant is Timer:
		return timer_variant as Timer
	return null

func _request_reload_when_empty() -> void:
	if weapon == null:
		return
	var uses_ammo := false
	if weapon.has_method("uses_ammo_system"):
		uses_ammo = bool(weapon.call("uses_ammo_system"))
	if uses_ammo and int(weapon.get("current_ammo")) <= 0 and weapon.has_method("request_reload"):
		weapon.call("request_reload")

func _notify_attack_speed_status(source_id: StringName, multiplier: float, active: bool) -> void:
	if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("notify_weapon_status_change"):
		PlayerData.player.call("notify_weapon_status_change", &"attack_speed_up" if multiplier > 1.0 else &"attack_speed_down", source_id, active)
