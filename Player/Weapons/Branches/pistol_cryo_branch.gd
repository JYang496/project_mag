extends WeaponBranchBehavior
class_name PistolCryoBranch

@export var shard_damage_ratio: float = 0.4
@export var shard_radius: float = 120.0
@export var shard_target_count: int = 1
@export var proc_every_hits: int = 3

@export var trail_color: Color = Color(0.42, 0.9, 1.0, 0.85)
@export var trail_width: float = 2.2
@export var trail_max_points: int = 14
@export var trail_sample_interval_sec: float = 0.012
@export var trail_fade_sec: float = 0.18

var _target_hit_counter: Dictionary = {}

func on_removed() -> void:
	_target_hit_counter.clear()

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FREEZE

func get_projectile_trail_config() -> Dictionary:
	return {
		"trail_color": trail_color,
		"trail_width": trail_width,
		"max_points": max(3, trail_max_points),
		"sample_interval_sec": maxf(trail_sample_interval_sec, 0.004),
		"trail_fade_sec": maxf(trail_fade_sec, 0.05),
	}

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	var target_id: int = target.get_instance_id()
	var hit_count: int = int(_target_hit_counter.get(target_id, 0)) + 1
	_target_hit_counter[target_id] = hit_count
	if hit_count % max(1, proc_every_hits) != 0:
		return
	_trigger_shard(target as Node2D, target)

func _trigger_shard(hit_target: Node2D, original_target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	var runtime_damage := 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var shard_damage: int = max(1, int(round(float(runtime_damage) * maxf(shard_damage_ratio, 0.0))))
	var candidates: Array[Node2D] = []
	for enemy_ref in weapon.get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy == original_target:
			continue
		if enemy.global_position.distance_to(hit_target.global_position) <= maxf(shard_radius, 1.0):
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(hit_target.global_position) < b.global_position.distance_to(hit_target.global_position)
	)
	var owner_player: Node = DamageManager.resolve_source_player(weapon)
	for i in range(mini(max(1, shard_target_count), candidates.size())):
		var chained_target: Node2D = candidates[i]
		var damage_data: DamageData = DamageData.new().setup(
			shard_damage,
			Attack.TYPE_FREEZE,
			{"amount": 0, "angle": Vector2.ZERO},
			weapon,
			owner_player
		)
		DamageManager.apply_to_target(chained_target, damage_data)
