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

func consume(amount: int = 1) -> bool:
	if not weapon.uses_ammo_system():
		return true
	var consume_amount := maxi(amount, 0)
	if consume_amount <= 0:
		return true
	if weapon.current_ammo < consume_amount:
		return false
	weapon.current_ammo -= consume_amount
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
	weapon.dispatch_passive_event(&"on_reload_started", {
		"source_weapon": weapon,
		"ammo_before": ammo_before,
		"ammo_after": weapon.current_ammo,
		"magazine_capacity": max(0, weapon.magazine_capacity),
		"spent_ratio": spent_ratio,
		"reload_duration": reload_duration,
	})
	if weapon.reload_time_left <= 0.0:
		finish_reload()
	return true

func update_reload_state(delta: float) -> void:
	if not weapon.uses_ammo_system():
		return
	if not weapon.is_reloading:
		return
	weapon.reload_time_left = maxf(0.0, weapon.reload_time_left - maxf(delta, 0.0))
	if weapon.reload_time_left <= 0.0:
		finish_reload()

func finish_reload() -> void:
	if not weapon.uses_ammo_system():
		return
	var ammo_before := weapon.current_ammo
	var spent_ratio := get_spent_magazine_ratio()
	weapon.current_ammo = max(0, weapon.magazine_capacity)
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0
	weapon._refresh_offhand_skill_on_reload()
	weapon.dispatch_passive_event(&"on_reload_finished", {
		"source_weapon": weapon,
		"ammo_before": ammo_before,
		"ammo_after": weapon.current_ammo,
		"magazine_capacity": max(0, weapon.magazine_capacity),
		"spent_ratio": spent_ratio,
	})
	weapon.weapon_reload_completed.emit(weapon)

func refill_instantly() -> void:
	if not weapon.uses_ammo_system():
		return
	weapon.current_ammo = max(0, weapon.magazine_capacity)
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0

func get_status() -> Dictionary:
	return {
		"enabled": weapon.uses_ammo_system(),
		"current": weapon.current_ammo,
		"max": max(0, weapon.magazine_capacity),
		"is_reloading": weapon.is_reloading,
		"reload_left": weapon.reload_time_left,
	}

func initialize_ammo_system() -> void:
	if not weapon.uses_ammo_system():
		weapon.current_ammo = 0
		weapon.is_reloading = false
		weapon.reload_time_left = 0.0
		return
	weapon.magazine_capacity = max(0, weapon.magazine_capacity)
	weapon.current_ammo = weapon.magazine_capacity
	weapon.is_reloading = false
	weapon.reload_time_left = 0.0

func get_spent_magazine_ratio() -> float:
	if weapon.magazine_capacity <= 0:
		return 0.0
	var spent: int = max(0, weapon.magazine_capacity - weapon.current_ammo)
	return clampf(float(spent) / float(weapon.magazine_capacity), 0.0, 1.0)

func get_effective_reload_duration() -> float:
	return weapon.plugin_dispatcher.get_effective_reload_duration(weapon.reload_duration_sec)

func clear_for_weapon_exit() -> void:
	pass
