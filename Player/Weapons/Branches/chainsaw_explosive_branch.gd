extends WeaponBranchBehavior
class_name ChainsawExplosiveBranch

@export var cooldown_multiplier: float = 1.0
@export var projectile_damage_multiplier: float = 1.0
@export var slow_speed_multiplier: float = 0.15
@export var growth_per_hit: float = 0.05
@export var explode_size_multiplier: float = 2.0
@export var explosion_radius: float = 56.0
@export var explosion_damage_ratio: float = 1.0
@export var explosion_duration: float = 0.08

var area_effect_scene: PackedScene = preload("res://Utility/area_effect/area_effect.tscn")
var _armed_projectiles: Dictionary = {}

func on_removed() -> void:
	_armed_projectiles.clear()

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func on_chainsaw_target_hit(_target: Node, projectile: Projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	projectile.set_meta("chainsaw_explosive_started", true)
	projectile.base_displacement *= clampf(slow_speed_multiplier, 0.05, 1.0)
	var projectile_id: int = projectile.get_instance_id()
	var entry: Dictionary = _armed_projectiles.get(projectile_id, {})
	var sprite: Sprite2D = projectile.get_node_or_null("Bullet/BulletSprite") as Sprite2D
	if entry.is_empty():
		var initial_sprite_scale: Vector2 = sprite.scale if sprite != null else Vector2.ONE
		entry = {
			"projectile_ref": weakref(projectile),
			"initial_size": maxf(projectile.size, 0.01),
			"growth_mul": 1.0,
			"initial_sprite_scale": initial_sprite_scale,
		}
	var growth_mul: float = float(entry.get("growth_mul", 1.0))
	growth_mul += maxf(growth_per_hit, 0.0)
	entry["growth_mul"] = growth_mul
	var initial_size: float = maxf(float(entry.get("initial_size", projectile.size)), 0.01)
	var next_size: float = initial_size * growth_mul
	projectile.size = next_size
	if sprite != null:
		var initial_sprite_scale2: Vector2 = entry.get("initial_sprite_scale", sprite.scale)
		sprite.scale = initial_sprite_scale2 * growth_mul
	_armed_projectiles[projectile_id] = entry
	if next_size >= initial_size * maxf(explode_size_multiplier, 1.01):
		_explode_projectile(projectile)
		_armed_projectiles.erase(projectile_id)

func _physics_process(delta: float) -> void:
	if _armed_projectiles.is_empty():
		return
	var to_remove: Array[int] = []
	for id_variant in _armed_projectiles.keys():
		var projectile_id: int = int(id_variant)
		var entry: Dictionary = _armed_projectiles[projectile_id]
		var projectile_ref: WeakRef = entry.get("projectile_ref", null)
		var projectile: Projectile = projectile_ref.get_ref() as Projectile if projectile_ref else null
		if projectile == null or not is_instance_valid(projectile):
			to_remove.append(projectile_id)
			continue
		var growth_mul: float = float(entry.get("growth_mul", 1.0))
		entry["growth_mul"] = growth_mul
		var initial_size: float = maxf(float(entry.get("initial_size", projectile.size)), 0.01)
		var next_size: float = initial_size * growth_mul
		projectile.size = next_size
		var sprite: Sprite2D = projectile.get_node_or_null("Bullet/BulletSprite") as Sprite2D
		if sprite != null:
			var initial_sprite_scale: Vector2 = entry.get("initial_sprite_scale", sprite.scale)
			sprite.scale = initial_sprite_scale * growth_mul
		_armed_projectiles[projectile_id] = entry
		if next_size >= initial_size * maxf(explode_size_multiplier, 1.01):
			_explode_projectile(projectile)
			to_remove.append(projectile_id)
	for projectile_id in to_remove:
		_armed_projectiles.erase(projectile_id)

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
	area_effect.global_position = projectile.global_position
	var spawn_parent: Node = projectile.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = projectile.get_tree().root
	spawn_parent.call_deferred("add_child", area_effect)
	projectile.call_deferred("despawn")
