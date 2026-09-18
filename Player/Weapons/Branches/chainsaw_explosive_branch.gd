extends WeaponBranchBehavior
class_name ChainsawExplosiveBranch

func get_added_delivery_types() -> Array[StringName]:
	return [DamageDeliveryType.AREA]

@export var cooldown_multiplier: float = 1.0
@export var projectile_damage_multiplier: float = 1.0
@export var hits_to_explode: int = 5
@export var explosion_radius: float = 56.0
@export var explosion_damage_ratio: float = 1.0
@export var explosion_duration: float = 0.08

var area_effect_scene: PackedScene = preload("res://Combat/area_effect/area_effect.tscn")
func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func on_chainsaw_target_hit(_target: Node, projectile: Projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var hit_count := int(projectile.get_meta("chainsaw_explosive_hits", 0)) + 1
	projectile.set_meta("chainsaw_explosive_hits", hit_count)
	if hit_count >= maxi(hits_to_explode, 1):
		_explode_projectile(projectile)

func _explode_projectile(projectile: Projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if bool(projectile.get_meta("chainsaw_explosive_triggered", false)):
		return
	projectile.set_meta("chainsaw_explosive_triggered", true)
	if area_effect_scene == null:
		projectile.call_deferred("despawn")
		return
	var area_effect: AreaEffect = area_effect_scene.instantiate() as AreaEffect
	if area_effect == null:
		projectile.call_deferred("despawn")
		return
	area_effect.radius = maxf(explosion_radius, 1.0)
	area_effect.one_shot_damage = maxi(1, int(round(float(projectile.damage) * maxf(explosion_damage_ratio, 0.0))))
	area_effect.damage_type = Attack.TYPE_PHYSICAL
	area_effect.duration = maxf(explosion_duration, 0.01)
	area_effect.apply_once_per_target = true
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	# Use branch node as source to avoid recursive branch on-hit loops.
	area_effect.source_node = self
	area_effect.source_category = DamageData.SOURCE_PLAYER_WEAPON
	area_effect.global_position = projectile.global_position
	var spawn_parent: Node = projectile.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = projectile.get_tree().root
	spawn_parent.call_deferred("add_child", area_effect)
	projectile.call_deferred("despawn")
