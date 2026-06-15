extends "res://Player/Weapons/Modules/wmod_on_hit_base.gd"
class_name SynergyModule

const DAMAGE_STATE_META := &"_incoming_damage_state"

var _damage_source_id: StringName
var _damage_buff_expires_at_msec: int = 0
var _damage_buff_multiplier: float = 1.0

func _enter_tree() -> void:
	super._enter_tree()
	_damage_source_id = StringName("module_%s_%s" % [name, str(get_instance_id())])
	set_physics_process(false)

func _exit_tree() -> void:
	super._exit_tree()
	clear_damage_buff()

func _physics_process(_delta: float) -> void:
	if _damage_buff_expires_at_msec > 0 and Time.get_ticks_msec() >= _damage_buff_expires_at_msec:
		clear_damage_buff()
	on_synergy_physics_process()

func on_synergy_physics_process() -> void:
	pass

func apply_damage_buff(multiplier: float, duration_sec: float) -> void:
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null:
		return
	_damage_buff_multiplier = maxf(multiplier, 1.0)
	_damage_buff_expires_at_msec = Time.get_ticks_msec() + int(maxf(duration_sec, 0.05) * 1000.0)
	weapon.apply_external_damage_mul(_damage_source_id, _damage_buff_multiplier)
	set_physics_process(true)

func clear_damage_buff() -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.remove_external_damage_mul(_damage_source_id)
	_damage_buff_expires_at_msec = 0
	_damage_buff_multiplier = 1.0

func get_level_value(lv1: float, lv2: float, lv3: float) -> float:
	return WeaponModuleRuntimeUtils.get_value_by_level(module_level, lv1, lv2, lv3)

func is_enemy_target(target: Node) -> bool:
	return target != null and is_instance_valid(target) and target.is_in_group("enemies")

func is_target_dead(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.get("is_dead") != null and bool(target.get("is_dead")):
		return true
	return target.get("hp") != null and int(target.get("hp")) <= 0

func has_negative_status(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("has_any_mark") and bool(target.call("has_any_mark")):
		return true
	var effects: Variant = target.get("status_effects")
	if effects is Array and not (effects as Array).is_empty():
		return true
	if target.has_meta(DAMAGE_STATE_META):
		var state: Variant = target.get_meta(DAMAGE_STATE_META)
		if state is Dictionary:
			return int(state.get("frost_stacks", 0)) > 0 or int(state.get("scorch_stacks", 0)) > 0
	return false

func get_ammo_ratio() -> float:
	if weapon == null or not weapon.uses_ammo_system():
		return 1.0
	var capacity := weapon.get_effective_magazine_capacity()
	return clampf(float(weapon.current_ammo) / float(maxi(capacity, 1)), 0.0, 1.0)

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	return super.get_incompatibility_reason(target_weapon)

func clear_timed_effects_for_prepare() -> void:
	clear_damage_buff()
