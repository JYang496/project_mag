class_name EnemyDeathVfxProfile
extends Resource

enum DeathType {
	PHYSICAL_SHATTER,
	ENERGY_COLLAPSE,
	FIRE_BURNOUT,
	FREEZE_SHATTER,
}

enum ScaleClass {
	SMALL,
	STANDARD,
	HEAVY,
	ELITE,
	BOSS,
}

@export var death_type: DeathType = DeathType.PHYSICAL_SHATTER
@export var scale_class: ScaleClass = ScaleClass.STANDARD
@export var core_color := Color.WHITE
@export var debris_color := Color(0.72, 0.82, 0.86, 1.0)
@export_range(0.20, 0.50, 0.01) var duration_sec := 0.30
@export_enum("32", "64", "128") var source_size := 64
@export_range(0.75, 2.5, 0.05) var effect_scale := 1.0
@export var exit_direction := Vector2.RIGHT


static func from_enemy(enemy: Node, killing_attack: Attack) -> Resource:
	var damage_type := killing_attack.damage_type if killing_attack != null else Attack.TYPE_PHYSICAL
	var direction := _resolve_exit_direction(killing_attack, enemy)
	if enemy == null:
		return create(resolve_type(damage_type), ScaleClass.STANDARD, direction)
	var is_elite := bool(enemy.call("has_spawn_tag", &"elite")) if enemy.has_method("has_spawn_tag") else false
	var is_boss := bool(enemy.get("is_boss")) if enemy.get("is_boss") != null else enemy.is_in_group("boss")
	var extent := Vector2.ZERO
	if enemy.has_method("_resolve_hurtbox_or_visible_sprite_extent"):
		extent = enemy.call("_resolve_hurtbox_or_visible_sprite_extent") as Vector2
	var spawn_cost := int(enemy.get("spawn_cost")) if enemy.get("spawn_cost") != null else 0
	return create(resolve_type(damage_type), resolve_scale_class(is_elite, is_boss, extent, spawn_cost), direction)


static func resolve_type(damage_type: StringName) -> DeathType:
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_ENERGY:
			return DeathType.ENERGY_COLLAPSE
		Attack.TYPE_FIRE:
			return DeathType.FIRE_BURNOUT
		Attack.TYPE_FREEZE:
			return DeathType.FREEZE_SHATTER
		_:
			return DeathType.PHYSICAL_SHATTER


static func resolve_scale_class(
	is_elite: bool,
	is_boss: bool,
	visual_extent: Vector2,
	spawn_cost: int
) -> ScaleClass:
	if is_boss:
		return ScaleClass.BOSS
	if is_elite:
		return ScaleClass.ELITE
	var largest_extent := maxf(visual_extent.x, visual_extent.y)
	if largest_extent > 0.0 and largest_extent <= 30.0 and spawn_cost <= 3:
		return ScaleClass.SMALL
	if largest_extent >= 48.0 or spawn_cost >= 8:
		return ScaleClass.HEAVY
	return ScaleClass.STANDARD


static func create(
	type: DeathType,
	rank: ScaleClass = ScaleClass.STANDARD,
	direction: Vector2 = Vector2.RIGHT
) -> Resource:
	var profile = load("res://Combat/Vfx/enemy_death_vfx_profile.gd").new()
	profile.death_type = type
	profile.scale_class = rank
	profile.exit_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	match type:
		DeathType.ENERGY_COLLAPSE:
			profile.duration_sec = 0.28
			profile.core_color = Color(0.82, 0.58, 1.0, 1.0)
			profile.debris_color = Color(0.38, 0.70, 1.0, 1.0)
		DeathType.FIRE_BURNOUT:
			profile.duration_sec = 0.32
			profile.core_color = Color(1.0, 0.86, 0.32, 1.0)
			profile.debris_color = Color(1.0, 0.34, 0.08, 1.0)
		DeathType.FREEZE_SHATTER:
			profile.duration_sec = 0.34
			profile.core_color = Color(0.78, 0.96, 1.0, 1.0)
			profile.debris_color = Color(0.36, 0.92, 1.0, 1.0)
		_:
			profile.duration_sec = 0.28
			profile.core_color = Color(1.0, 0.90, 0.76, 1.0)
			profile.debris_color = Color(0.68, 0.76, 0.78, 1.0)
	match rank:
		ScaleClass.SMALL:
			profile.source_size = 32
			profile.effect_scale = 0.82
			profile.duration_sec *= 0.90
		ScaleClass.HEAVY:
			profile.source_size = 128
			profile.effect_scale = 1.30
			profile.duration_sec *= 1.10
		ScaleClass.ELITE:
			profile.source_size = 128
			profile.effect_scale = 1.65
			profile.duration_sec *= 1.18
		ScaleClass.BOSS:
			profile.source_size = 128
			profile.effect_scale = 2.20
			profile.duration_sec = minf(profile.duration_sec * 1.35, 0.46)
		_:
			profile.source_size = 64
			profile.effect_scale = 1.0
	profile.duration_sec = clampf(profile.duration_sec, 0.20, 0.50)
	return profile


static func _resolve_exit_direction(killing_attack: Attack, enemy: Node) -> Vector2:
	if killing_attack == null:
		return Vector2.RIGHT
	var knockback: Variant = killing_attack.knock_back.get("angle", Vector2.ZERO)
	if knockback is Vector2 and (knockback as Vector2).length_squared() > 0.0001:
		return (knockback as Vector2).normalized()
	if killing_attack.source_node is Node2D and is_instance_valid(killing_attack.source_node) and enemy is Node2D:
		var source_position := (killing_attack.source_node as Node2D).global_position
		var hit_direction := (enemy as Node2D).global_position - source_position
		if hit_direction.length_squared() > 0.0001:
			return hit_direction.normalized()
	return Vector2.RIGHT
