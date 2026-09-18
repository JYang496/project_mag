extends WeaponBranchBehavior
class_name ShotgunShatterBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.FREEZE, WeaponTrait.HEAT]

func get_suppressed_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.PHYSICAL]

@export var shatter_damage_ratio: float = 0.25
@export var shatter_required_hits: int = 3
var _target_hits: Dictionary = {}

func on_removed() -> void:
	_target_hits.clear()

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FREEZE

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	var hits := int(_target_hits.get(target_id, 0)) + 1
	if hits >= maxi(shatter_required_hits, 1):
		hits = 0
		_trigger_shatter(target)
	_target_hits[target_id] = hits

func _trigger_shatter(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var runtime_damage := weapon.get_runtime_damage()
	var shatter_damage: int = max(1, int(round(float(runtime_damage) * maxf(shatter_damage_ratio, 0.0))))
	var damage_data: DamageData = DamageData.new().setup(
		shatter_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		weapon,
		DamageManager.resolve_source_player(weapon),
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)
	DamageManager.apply_to_target(target, damage_data)
