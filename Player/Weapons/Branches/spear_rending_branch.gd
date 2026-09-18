extends WeaponBranchBehavior
class_name SpearRendingBranch

@export var damage_bonus_per_hit: float = 0.25
@export var cooldown_multiplier: float = 1.0

var _active_target_id: int = 0
var _active_target_hits: int = 0

func on_removed() -> void:
	_active_target_id = 0
	_active_target_hits = 0

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return

	var target_id: int = target.get_instance_id()
	if target_id != _active_target_id:
		_active_target_id = target_id
		_active_target_hits = 0
	_active_target_hits += 1
	var damage_multiplier := 1.0 + float(_active_target_hits - 1) * maxf(damage_bonus_per_hit, 0.0)

	# 如果不是第一次命中，造成额外伤害
	if _active_target_hits > 1:
		_apply_rending_damage(target, damage_multiplier)

func _apply_rending_damage(target: Node, damage_multiplier: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return

	var runtime_damage := weapon.get_runtime_damage()

	# 计算额外伤害：基础伤害 * (当前倍率 - 1)
	# 例如：第2次命中时倍率为1.25，额外伤害 = base * 0.25
	var extra_damage: int = max(1, int(round(float(runtime_damage) * (damage_multiplier - 1.0))))
	if extra_damage <= 0:
		return

	var damage_data: DamageData = DamageData.new().setup(
		extra_damage,
		Attack.TYPE_PHYSICAL,
		{"amount": 0, "angle": Vector2.ZERO},
		weapon,
		DamageManager.resolve_source_player(weapon),
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)
	DamageManager.apply_to_target(target, damage_data)
