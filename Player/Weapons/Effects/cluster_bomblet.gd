extends Node2D
class_name ClusterBomblet

const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

var source_weapon: Weapon
var velocity := Vector2.ZERO
var fuse_sec := 0.38
var radius := 46.0
var hit_counts: Dictionary
var _elapsed := 0.0
var _projected_streak: Line2D

func setup(weapon: Weapon, direction: Vector2, shared_hit_counts: Dictionary) -> ClusterBomblet:
	source_weapon = weapon
	velocity = direction.normalized() * 260.0
	hit_counts = shared_hit_counts
	return self

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_projected_streak = Line2D.new()
	_projected_streak.width = 12.0
	_projected_streak.default_color = Color(1.0, 0.42, 0.12, 0.95)
	_projected_streak.points = PackedVector2Array([Vector2(-10.0, 0.0), Vector2(10.0, 0.0)])
	_projected_streak.rotation = velocity.angle()
	_projected_streak.set_meta(&"hybrid_ground_visible", true)
	_projected_streak.set_meta(&"hybrid_segment_style", &"beam")
	_projected_streak.set_meta(&"hybrid_segment_endpoints", true)
	add_child(_projected_streak)
	HYBRID_GROUND_REGISTRATION.register(_projected_streak, &"register_ground_segment")
	queue_redraw()

func _exit_tree() -> void:
	if _projected_streak != null:
		HYBRID_GROUND_REGISTRATION.unregister(_projected_streak)

func cleanup_for_battle_end() -> void:
	queue_free()

func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_elapsed += step
	position += velocity * step
	if _projected_streak != null:
		_projected_streak.rotation = velocity.angle()
	velocity *= pow(0.04, step)
	queue_redraw()
	if _elapsed >= fuse_sec:
		_explode()
		queue_free()

func _explode() -> void:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), global_position, radius):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.global_position.distance_to(global_position) > radius:
			continue
		var target_id := enemy.get_instance_id()
		var previous_hits := int(hit_counts.get(target_id, 0))
		var diminishing := pow(0.65, previous_hits)
		hit_counts[target_id] = previous_hits + 1
		var amount: int = maxi(1, int(round(float(source_weapon.get_runtime_damage()) * 0.30 * diminishing)))
		var data := DamageManager.build_damage_data(
			source_weapon, amount, Attack.TYPE_FIRE,
			{"amount": 25.0, "angle": global_position.direction_to(enemy.global_position)},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA
		)
		DamageManager.apply_to_target(enemy, data)

func _draw() -> void:
	var pulse := 0.75 + sin(_elapsed * 24.0) * 0.2
	draw_circle(Vector2.ZERO, 7.0 * pulse, Color(1.0, 0.42, 0.16, 0.95))
	draw_line(Vector2.ZERO, -velocity.normalized() * 14.0, Color(1.0, 0.78, 0.3, 0.75), 3.0)
