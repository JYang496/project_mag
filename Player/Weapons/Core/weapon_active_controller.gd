extends RefCounted
class_name WeaponActiveController

var weapon: Weapon
var cooldown_remaining: float = 0.0
var hit_window_hits: int = 0
var hit_window_expires_at_msec: int = 0

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func request_weapon_active() -> Dictionary:
	if not weapon.is_attack_phase_allowed():
		weapon.weapon_active_triggered.emit(false, "phase")
		return {"ok": false, "reason": "phase"}
	if not weapon.is_main_weapon():
		weapon.weapon_active_triggered.emit(false, "not_main")
		return {"ok": false, "reason": "not_main"}
	if cooldown_remaining > 0.0:
		weapon.weapon_active_triggered.emit(false, "cd")
		return {"ok": false, "reason": "cd"}
	if not can_pay_resource():
		weapon.weapon_active_triggered.emit(false, "resource")
		return {"ok": false, "reason": "resource"}
	var damage_multiplier := consume_hit_window_bonus()
	var executed := weapon._execute_weapon_active(damage_multiplier)
	if not executed:
		weapon.weapon_active_triggered.emit(false, "condition")
		return {"ok": false, "reason": "condition"}
	pay_resource()
	cooldown_remaining = maxf(weapon.weapon_active_cooldown_sec, 0.0)
	weapon.weapon_active_status_changed.emit(cooldown_remaining, cooldown_remaining <= 0.0)
	weapon.weapon_active_triggered.emit(true, "")
	return {"ok": true, "reason": "", "damage_multiplier": damage_multiplier}

func get_cooldown_remaining() -> float:
	return maxf(cooldown_remaining, 0.0)

func get_cooldown_ratio() -> float:
	if weapon.weapon_active_cooldown_sec <= 0.0:
		return 0.0
	return clampf(cooldown_remaining / weapon.weapon_active_cooldown_sec, 0.0, 1.0)

func get_hit_window_progress() -> Dictionary:
	return {
		"hits": hit_window_hits,
		"required_hits": max(0, weapon.weapon_active_hit_window_required_hits),
		"active": hit_window_hits > 0 and hit_window_expires_at_msec > Time.get_ticks_msec(),
	}

func force_ready() -> void:
	cooldown_remaining = 0.0
	weapon.weapon_active_status_changed.emit(0.0, true)

func update_cooldown(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	var previous := cooldown_remaining
	cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(delta, 0.0))
	if int(ceil(previous * 10.0)) != int(ceil(cooldown_remaining * 10.0)):
		weapon.weapon_active_status_changed.emit(cooldown_remaining, cooldown_remaining <= 0.0)

func register_hit_window() -> void:
	if weapon.weapon_active_hit_window_required_hits <= 0:
		return
	hit_window_hits = mini(weapon.weapon_active_hit_window_required_hits, hit_window_hits + 1)
	hit_window_expires_at_msec = Time.get_ticks_msec() + int(maxf(weapon.weapon_active_hit_window_timeout_sec, 0.1) * 1000.0)

func update_hit_window() -> void:
	if hit_window_hits <= 0:
		return
	if Time.get_ticks_msec() < hit_window_expires_at_msec:
		return
	clear_hit_window()

func clear_hit_window() -> void:
	hit_window_hits = 0
	hit_window_expires_at_msec = 0

func consume_hit_window_bonus() -> float:
	if weapon.weapon_active_hit_window_required_hits <= 0:
		return 1.0
	var ready := hit_window_hits >= weapon.weapon_active_hit_window_required_hits
	clear_hit_window()
	if ready:
		return maxf(weapon.weapon_active_hit_window_bonus_multiplier, 1.0)
	return 1.0

func can_pay_resource() -> bool:
	var normalized_type := str(weapon.weapon_active_resource_type).to_lower()
	if normalized_type == "none" or weapon.weapon_active_resource_cost <= 0.0:
		return true
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return false
	if normalized_type == "energy":
		if not PlayerData.player.has_method("get_current_energy"):
			return false
		return float(PlayerData.player.call("get_current_energy")) >= weapon.weapon_active_resource_cost
	if normalized_type == "heat":
		return weapon.get_heat_value() >= weapon.weapon_active_resource_cost
	return false

func pay_resource() -> void:
	var normalized_type := str(weapon.weapon_active_resource_type).to_lower()
	if normalized_type == "none" or weapon.weapon_active_resource_cost <= 0.0:
		return
	if normalized_type == "energy":
		if PlayerData.player and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("consume_energy"):
			PlayerData.player.call("consume_energy", weapon.weapon_active_resource_cost)
		return
	if normalized_type == "heat":
		var core := weapon._get_active_heat_core()
		if core == null:
			return
		core.heat_value = maxf(0.0, float(core.heat_value) - weapon.weapon_active_resource_cost)
		if float(core.heat_value) < float(core.max_heat):
			core.overheated = false

func clear_for_weapon_exit() -> void:
	cooldown_remaining = 0.0
	clear_hit_window()
