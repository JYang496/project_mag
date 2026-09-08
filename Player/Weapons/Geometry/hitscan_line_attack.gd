extends Node2D
class_name HitscanLineAttack

const ENEMY_HURTBOX_MASK := 1 << 2
const DEFAULT_WORLD_BLOCKER_MASK := 1 << 5
const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

static func collect_ordered_targets(
	weapon: Node2D,
	origin: Vector2,
	direction: Vector2,
	max_distance: float,
	line_width: float,
	world_blocker_mask: int = DEFAULT_WORLD_BLOCKER_MASK,
	max_results: int = 128
) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon) or not weapon.is_inside_tree():
		return {"end_position": origin, "targets": []}
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction == Vector2.ZERO:
		return {"end_position": origin, "targets": []}
	var distance: float = maxf(max_distance, 1.0)
	var end_position: Vector2 = origin + normalized_direction * distance
	var space_state: PhysicsDirectSpaceState2D = weapon.get_world_2d().direct_space_state
	if world_blocker_mask > 0:
		var wall_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, end_position, world_blocker_mask)
		wall_query.collide_with_areas = false
		wall_query.collide_with_bodies = true
		var wall_hit: Dictionary = space_state.intersect_ray(wall_query)
		if not wall_hit.is_empty():
			end_position = wall_hit.get("position", end_position) as Vector2
	var effective_length: float = origin.distance_to(end_position)
	if effective_length <= 0.01:
		return {"end_position": end_position, "targets": []}
	var shape := RectangleShape2D.new()
	shape.size = Vector2(effective_length, maxf(line_width, 1.0))
	var enemy_query := PhysicsShapeQueryParameters2D.new()
	enemy_query.shape = shape
	enemy_query.transform = Transform2D(normalized_direction.angle(), origin.lerp(end_position, 0.5))
	enemy_query.collision_mask = ENEMY_HURTBOX_MASK
	enemy_query.collide_with_areas = true
	enemy_query.collide_with_bodies = false
	var ordered: Array[Dictionary] = []
	var seen_targets: Dictionary = {}
	for hit in space_state.intersect_shape(enemy_query, maxi(max_results, 1)):
		var collider: Variant = hit.get("collider", null)
		if not collider is HurtBox:
			continue
		var target: Node2D = _resolve_hurtbox_target(collider as HurtBox)
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var projection: float = clampf((target.global_position - origin).dot(normalized_direction), 0.0, effective_length)
		ordered.append({"target": target, "distance": projection})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	return {"end_position": end_position, "targets": ordered}

static func spawn_tracer(parent: Node, origin: Vector2, end_position: Vector2, width: float, duration: float, brightness: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var tracer := Node2D.new()
	var line := Line2D.new()
	line.width = maxf(width, 1.0)
	line.default_color = Color(1.0, 0.9, 0.62, 0.92 * brightness)
	line.points = PackedVector2Array([Vector2.ZERO, end_position - origin])
	line.set_meta(&"hybrid_ground_visible", true)
	line.set_meta(&"hybrid_segment_style", &"beam")
	tracer.add_child(line)
	parent.add_child(tracer)
	tracer.global_position = origin
	tracer.add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	if HYBRID_GROUND_REGISTRATION.register(line, &"register_ground_segment"):
		line.visible = false
	tracer.tree_exiting.connect(func() -> void: HYBRID_GROUND_REGISTRATION.unregister(line), CONNECT_ONE_SHOT)
	var fade := tracer.create_tween()
	fade.tween_property(line, "default_color:a", 0.0, maxf(duration, 0.01))
	fade.tween_callback(tracer.queue_free)

static func _resolve_hurtbox_target(hurt_box: HurtBox) -> Node2D:
	var target: Node = null
	if hurt_box.has_method("get_damage_target"):
		target = hurt_box.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	return target as Node2D
