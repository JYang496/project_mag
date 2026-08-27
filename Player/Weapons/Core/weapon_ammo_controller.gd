extends RefCounted
class_name WeaponAmmoController

var weapon: Weapon

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func can_fire() -> bool:
	if not weapon.uses_ammo_system():
		return true
	if weapon.is_reloading:
		return false
	return weapon.current_ammo > 0

func apply_level_ammo(level_data: Dictionary) -> void:
	if level_data == null:
		return
	if not level_data.has("ammo"):
		return
	var next_mag := maxi(0, int(level_data.get("ammo", weapon.magazine_capacity)))
	if next_mag <= 0:
		return
	weapon.magazine_capacity = next_mag
	if weapon.uses_ammo_system():
		refill_instantly()

func reconcile_capacity() -> void:
	if not weapon.uses_ammo_system():
		return
	weapon.current_ammo = mini(maxi(weapon.current_ammo, 0), _get_effective_capacity())

func consume(amount: int = 1) -> bool:
	if not weapon.uses_ammo_system():
		return true
	var consume_amount := maxi(amount, 0)
	if consume_amount <= 0:
		return true
	if weapon.current_ammo < consume_amount:
		return false
	var ammo_before := weapon.current_ammo
	weapon.current_ammo -= consume_amount
	weapon.trigger_runtime.on_ammo_consumed(ammo_before, weapon.current_ammo, _get_effective_capacity())
	return true

func request_reload() -> bool:
	if not weapon.uses_ammo_system():
		return false
	if weapon.is_reloading:
		return false
	var ammo_before := weapon.current_ammo
	var reload_duration := get_effective_reload_duration()
	var spent_ratio := get_spent_magazine_ratio()
	weapon.is_reloading = true
	weapon.reload_time_left = reload_duration
	var detail := {
		"source_weapon": weapon,
		"ammo_before": ammo_before,
		"ammo_after": weapon.current_ammo,
		"magazine_capacity": _get_effective_capacity(),
		"spent_ratio": spent_ratio,
		"reload_duration": reload_duration,
	}
	weapon.trigger_runtime.on_reload_started(detail)
	var event := WeaponEvent.create(WeaponEvent.RELOAD_STARTED, weapon)
	event.detail = detail
	weapon.emit_weapon_event(event)
	weapon.dispatch_passive_event(&"on_reload_started", detail)
	if weapon.reload_time_left <= 0.0:
		finish_reload()
	return true

func update_reload_state(delta: float) -> void:
	if not weapon.uses_ammo_system():
		return
	if not weapon.is_reloading:
		return
	var reload_progress := maxf(delta, 0.0) * _get_global_reload_speed_multiplier()
	weapon.reload_time_left = maxf(0.0, weapon.reload_time_left - reload_progress)
	if weapon.reload_time_left <= 0.0:
		finish_reload()

func finish_reload() -> void:
	if not weapon.uses_ammo_system():
		return
	var ammo_before := weapon.current_ammo
	var spent_ratio := get_spent_magazine_ratio()
	weapon.current_ammo = _get_effective_capacity()
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0
	var detail := {
		"source_weapon": weapon,
		"ammo_before": ammo_before,
		"ammo_after": weapon.current_ammo,
		"magazine_capacity": _get_effective_capacity(),
		"spent_ratio": spent_ratio,
	}
	var event := WeaponEvent.create(WeaponEvent.RELOAD_FINISHED, weapon)
	event.detail = detail
	weapon.emit_weapon_event(event)
	weapon.weapon_reload_completed.emit(weapon)

func refill_instantly() -> void:
	if not weapon.uses_ammo_system():
		return
	weapon.current_ammo = _get_effective_capacity()
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0

func get_status() -> Dictionary:
	return {
		"enabled": weapon.uses_ammo_system(),
		"current": weapon.current_ammo,
		"max": _get_effective_capacity(),
		"is_reloading": weapon.is_reloading,
		"reload_left": weapon.reload_time_left,
		"reload_total": get_effective_reload_duration(),
	}

func initialize_ammo_system() -> void:
	if not weapon.uses_ammo_system():
		weapon.current_ammo = 0
		weapon.is_reloading = false
		weapon.reload_time_left = 0.0
		return
	weapon.magazine_capacity = max(0, weapon.magazine_capacity)
	weapon.current_ammo = _get_effective_capacity()
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0

func get_spent_magazine_ratio() -> float:
	var effective_capacity := _get_effective_capacity()
	if effective_capacity <= 0:
		return 0.0
	var spent: int = max(0, effective_capacity - weapon.current_ammo)
	return clampf(float(spent) / float(effective_capacity), 0.0, 1.0)

func get_effective_reload_duration() -> float:
	var module_duration := weapon.get_runtime_stat_value("reload_duration_sec", weapon.reload_duration_sec)
	var plugin_duration := weapon.plugin_dispatcher.get_effective_reload_duration(module_duration)
	return plugin_duration * _get_cold_reload_duration_multiplier()

func _get_cold_reload_duration_multiplier() -> float:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return 1.0
	if not PlayerData.player.has_method("get_cold_reload_duration_multiplier"):
		return 1.0
	return maxf(float(PlayerData.player.call("get_cold_reload_duration_multiplier")), 0.1)

func _get_global_reload_speed_multiplier() -> float:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return 1.0
	if not PlayerData.player.has_method("get_total_reload_speed_mul"):
		return 1.0
	return maxf(float(PlayerData.player.call("get_total_reload_speed_mul")), 0.05)

func _get_effective_capacity() -> int:
	if weapon.has_method("get_effective_magazine_capacity"):
		return maxi(1, int(weapon.call("get_effective_magazine_capacity")))
	return maxi(1, int(weapon.magazine_capacity))

func clear_for_weapon_exit() -> void:
	pass
