extends WeaponBranchBehavior
class_name SniperImpactBurstBranch

@export var cooldown_multiplier: float = 1.12
@export var projectile_damage_multiplier: float = 0.88
@export var burst_radius: float = 58.0
@export var burst_damage_ratio: float = 0.55
@export var burst_duration: float = 0.08

var area_effect_scene: PackedScene = preload("res://Utility/area_effect/area_effect.tscn")

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func on_target_hit(target: Node) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if target == null or not is_instance_valid(target):
		return
	var target_node := target as Node2D
	if target_node == null:
		return
	if area_effect_scene == null:
		return
	var area_effect := area_effect_scene.instantiate() as AreaEffect
	if area_effect == null:
		return
	var runtime_damage := 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	area_effect.radius = maxf(burst_radius, 1.0)
	area_effect.one_shot_damage = max(1, int(round(float(runtime_damage) * maxf(burst_damage_ratio, 0.0))))
	area_effect.damage_type = Attack.TYPE_PHYSICAL
	area_effect.apply_once_per_target = true
	area_effect.duration = maxf(burst_duration, 0.01)
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	# Use branch node as source to avoid recursive weapon on_hit->branch->AoE loops.
	area_effect.source_node = self
	area_effect.global_position = target_node.global_position
	var spawn_parent := weapon.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = weapon.get_tree().root
	spawn_parent.call_deferred("add_child", area_effect)

