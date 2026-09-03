extends WeaponBranchBehavior
class_name DashReturnExecuteBranch

@export var damage_multiplier: float = 0.90
@export var return_bonus_damage_ratio: float = 0.70
@export var missing_health_execute_scale: float = 0.80

var _outbound_target_id: int = 0
var _outbound_target_ref: WeakRef
var _return_triggered: bool = false

func get_damage_multiplier() -> float:
	return maxf(damage_multiplier, 0.05)

func wants_dash_return_hitbox() -> bool:
	return true

func on_dash_cycle_started() -> void:
	_clear_cycle()

func on_dash_return_started() -> void:
	_return_triggered = false

func on_dash_cycle_finished() -> void:
	_clear_cycle()

func on_removed() -> void:
	_clear_cycle()
	super.on_removed()

func on_dash_target_hit(target: Node, is_returning: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not is_returning:
		if _outbound_target_id == 0:
			_outbound_target_id = target.get_instance_id()
			_outbound_target_ref = weakref(target)
		return
	if _return_triggered or target.get_instance_id() != _outbound_target_id:
		return
	if _outbound_target_ref == null or _outbound_target_ref.get_ref() != target:
		return
	_return_triggered = true
	_apply_return_execute(target)

func _apply_return_execute(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var runtime_damage := weapon.get_runtime_damage()
	var missing_ratio := 0.0
	if target.has_method("get_health_ratio"):
		missing_ratio = 1.0 - clampf(float(target.call("get_health_ratio")), 0.0, 1.0)
	var bonus_ratio := maxf(return_bonus_damage_ratio, 0.0) \
		* (1.0 + missing_ratio * maxf(missing_health_execute_scale, 0.0))
	var bonus_damage := maxi(1, int(round(float(runtime_damage) * bonus_ratio)))
	var data := DamageData.new().setup(
		bonus_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		weapon,
		DamageManager.resolve_source_player(weapon),
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.MELEE_CONTACT
	)
	data.damage_kind = DamageData.KIND_DIRECT
	data.suppress_reactive_effects = true
	data.dedupe_token = StringName("dash_return_execute_%d_%d" % [
		weapon.get_instance_id(),
		target.get_instance_id(),
	])
	DamageManager.apply_to_target(target, data)
	weapon.emit_passive_trigger(&"dash_return_execute", {
		"target": target,
		"missing_health_ratio": missing_ratio,
		"bonus_damage": bonus_damage,
		"return_bonus_ratio": bonus_ratio,
	}, Weapon.PASSIVE_SCOPE_GLOBAL)

func _clear_cycle() -> void:
	_outbound_target_id = 0
	_outbound_target_ref = null
	_return_triggered = false
