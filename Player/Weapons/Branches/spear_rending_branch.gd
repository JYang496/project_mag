extends WeaponBranchBehavior
class_name SpearRendingBranch

@export var damage_bonus_per_hit: float = 0.25
@export var max_damage_multiplier: float = 2.0
@export var combo_window_sec: float = 2.5
@export var cooldown_multiplier: float = 1.0

var _target_combo_hits: Dictionary = {}

func on_removed() -> void:
	_target_combo_hits.clear()

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return

	var target_id: int = target.get_instance_id()
	var now_sec: float = Time.get_ticks_msec() / 1000.0

	var entry: Dictionary = _target_combo_hits.get(target_id, {
		"combo_start": now_sec,
		"hits": 0,
	})

	var combo_start: float = float(entry.get("combo_start", now_sec))
	var hits: int = int(entry.get("hits", 0))

	# 检查是否超出连击窗口，重置连击
	if now_sec - combo_start > combo_window_sec:
		combo_start = now_sec
		hits = 0

	hits += 1
	entry["combo_start"] = combo_start
	entry["hits"] = hits

	# 计算伤害倍率：1 + (hits - 1) * bonus
	var damage_multiplier := 1.0 + float(hits - 1) * damage_bonus_per_hit
	damage_multiplier = minf(damage_multiplier, max_damage_multiplier)
	entry["damage_multiplier"] = damage_multiplier

	_target_combo_hits[target_id] = entry

	# 如果不是第一次命中，造成额外伤害
	if hits > 1:
		_apply_rending_damage(target, damage_multiplier)

func _apply_rending_damage(target: Node, damage_multiplier: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return

	var runtime_damage: int = 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))

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
		DamageManager.resolve_source_player(weapon)
	)
	DamageManager.apply_to_target(target, damage_data)
