extends WeaponBranchBehavior
class_name PistolArcBranch

@export var chain_count: int = 2
@export var chain_radius: float = 240.0
@export var chain_damage_ratio_1: float = 0.65
@export var chain_damage_ratio_2: float = 0.40

@export var trail_color: Color = Color(0.55, 0.75, 1.0, 0.9)
@export var trail_width: float = 2.5
@export var trail_max_points: int = 16
@export var trail_sample_interval_sec: float = 0.010
@export var trail_fade_sec: float = 0.2

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

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
	if not target.is_in_group("enemies"):
		return
	var center := target as Node2D
	if center == null:
		return

	var ratios := [chain_damage_ratio_1, chain_damage_ratio_2]
	var candidates: Array[Node2D] = []
	for enemy_ref in weapon.get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy == null or enemy == center:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center.global_position) <= maxf(chain_radius, 1.0):
			candidates.append(enemy)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(center.global_position) < b.global_position.distance_to(center.global_position)
	)

	var runtime_damage := 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var hops := mini(max(0, chain_count), candidates.size())
	for i in range(hops):
		var ratio: float = ratios[min(i, ratios.size() - 1)] if not ratios.is_empty() else 0.5
		var chain_damage: int = max(1, int(round(float(runtime_damage) * maxf(ratio, 0.05))))
		var chain_data := DamageManager.build_damage_data(
			weapon,
			chain_damage,
			Attack.TYPE_ENERGY,
			{"amount": 0, "angle": Vector2.ZERO}
		)
		if DamageManager.apply_to_target(candidates[i], chain_data):
			var owner_player := chain_data.source_player as Player
			if owner_player and is_instance_valid(owner_player):
				owner_player.apply_bonus_hit_if_needed(candidates[i])
