extends Node
class_name WeaponHeatController

const HEAT_SCRIPT := preload("res://Player/Weapons/Heat/heat.gd")

var weapon: Weapon
var heat_core: Heat

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon
	_sync_weapon_heat_core()

func has_heat_system() -> bool:
	if not _has_heat_trait():
		return false
	var shared_pool := get_shared_heat_pool()
	if shared_pool != null:
		return true
	return heat_core != null

func can_fire() -> bool:
	var core := get_active_heat_core()
	if core == null:
		return true
	return core.can_fire()

func configure(per_shot: float, max_value: float, cool_rate: float) -> void:
	if not _has_valid_weapon():
		return
	weapon.heat_per_shot = maxf(per_shot, 0.0)
	weapon.heat_max_value = maxf(max_value, 1.0)
	weapon.heat_cool_rate = maxf(cool_rate, 0.0)
	sync_trait_state()
	if heat_core != null:
		heat_core.configure(weapon.heat_per_shot, weapon.heat_max_value, weapon.heat_cool_rate)
	notify_shared_heat_pool_dirty()

func register_shot(multiplier: float = 1.0) -> void:
	if not _has_heat_trait():
		return
	var core := get_active_heat_core()
	if core == null:
		return
	if core.has_method("add_heat_amount"):
		core.call("add_heat_amount", maxf(0.0, weapon.heat_per_shot * maxf(multiplier, 0.0)))
		return
	core.add_heat(multiplier)

func get_heat_ratio() -> float:
	var core := get_active_heat_core()
	if core == null:
		return 0.0
	return core.get_ratio()

func get_heat_value() -> float:
	var core := get_active_heat_core()
	if core == null:
		return 0.0
	return float(core.heat_value)

func get_heat_max_value() -> float:
	var core := get_active_heat_core()
	if core == null:
		return 0.0
	if core.has_method("has_contributors") and not bool(core.call("has_contributors")):
		return 0.0
	return float(core.max_heat)

func get_heat_percent() -> int:
	var core := get_active_heat_core()
	if core == null:
		return 0
	return core.get_percent()

func is_overheated() -> bool:
	var core := get_active_heat_core()
	if core == null:
		return false
	return bool(core.overheated)

func lock_heat_value(value: float, duration_sec: float) -> void:
	var core := get_active_heat_core()
	if core == null:
		return
	core.lock_to_value(value, duration_sec)

func sync_trait_state() -> void:
	notify_shared_heat_pool_dirty()
	var shared_pool := get_shared_heat_pool()
	if shared_pool != null:
		heat_core = null
		_sync_weapon_heat_core()
		return
	if _has_heat_trait():
		if heat_core == null:
			heat_core = HEAT_SCRIPT.new() as Heat
		if heat_core != null:
			heat_core.configure(weapon.heat_per_shot, weapon.heat_max_value, weapon.heat_cool_rate)
		_sync_weapon_heat_core()
		return
	heat_core = null
	_sync_weapon_heat_core()

func update(delta: float) -> void:
	if get_shared_heat_pool() != null:
		return
	if heat_core == null:
		return
	heat_core.cool_down(delta)

func get_shared_heat_pool() -> Heat:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return null
	if not PlayerData.player.has_method("get_shared_heat_pool"):
		return null
	var pool: Variant = PlayerData.player.call("get_shared_heat_pool")
	if pool == null:
		return null
	return pool as Heat

func get_active_heat_core() -> Heat:
	var shared_pool := get_shared_heat_pool()
	if shared_pool != null:
		return shared_pool
	return heat_core

func notify_shared_heat_pool_dirty() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	if PlayerData.player.has_method("mark_shared_heat_pool_dirty"):
		PlayerData.player.call("mark_shared_heat_pool_dirty")

func clear_for_weapon_exit() -> void:
	heat_core = null
	_sync_weapon_heat_core()

func _has_valid_weapon() -> bool:
	return weapon != null and is_instance_valid(weapon)

func _has_heat_trait() -> bool:
	if not _has_valid_weapon():
		return false
	return weapon.has_heat_trait()

func _sync_weapon_heat_core() -> void:
	if _has_valid_weapon():
		weapon.heat_core = heat_core
