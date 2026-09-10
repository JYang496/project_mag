extends Node2D
class_name PersistentGroundArea

const ENEMY_HURTBOX_MASK := 1 << 2
const EXTEND_DURATION_SEC := 0.32
const CRUMBLE_START_RATIO := 0.8

var source_weapon: Node
var path_length := 200.0
var path_width := 44.0
var segment_spacing := 18.0
var duration_sec := 1.6
var tick_interval_sec := 0.12
var cold_snap_active := false
var _elapsed_sec := 0.0
var _tick_elapsed_sec := 0.0
var _cold_snap_target_ids: Dictionary = {}
var _configured_global_origin := Vector2.ZERO

func setup(
	weapon: Node,
	origin: Vector2,
	direction: Vector2,
	length_value: float,
	width_value: float,
	spacing_value: float,
	duration_value: float,
	tick_value: float,
	cold_snap_value: bool
) -> PersistentGroundArea:
	source_weapon = weapon
	_configured_global_origin = origin
	global_position = origin
	rotation = direction.normalized().angle()
	path_length = maxf(length_value, 1.0)
	path_width = maxf(width_value, 1.0)
	segment_spacing = maxf(spacing_value, 2.0)
	duration_sec = maxf(duration_value, 0.05)
	tick_interval_sec = maxf(tick_value, 0.02)
	cold_snap_active = cold_snap_value
	return self

func _ready() -> void:
	global_position = _configured_global_origin
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	_create_ground_visual()
	queue_redraw()
	_apply_tick()

func _physics_process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	_elapsed_sec += step
	_tick_elapsed_sec += step
	if _elapsed_sec >= duration_sec:
		queue_free()
		return
	if _tick_elapsed_sec >= tick_interval_sec:
		_tick_elapsed_sec = fmod(_tick_elapsed_sec, tick_interval_sec)
		_apply_tick()
	queue_redraw()

func cleanup_for_battle_end() -> void:
	queue_free()

func get_extension_progress() -> float:
	var extend_duration := minf(EXTEND_DURATION_SEC, duration_sec * 0.3)
	return clampf(_elapsed_sec / maxf(extend_duration, 0.001), 0.0, 1.0)

func get_crumble_progress() -> float:
	return clampf((_elapsed_sec / duration_sec - CRUMBLE_START_RATIO) / (1.0 - CRUMBLE_START_RATIO), 0.0, 1.0)

func get_damage_length() -> float:
	# Drifting fragments are cosmetic; only the intact growing trail can hit.
	if _elapsed_sec >= duration_sec * CRUMBLE_START_RATIO:
		return 0.0
	return path_length * get_extension_progress()

func _create_ground_visual() -> void:
	var visual := preload("res://Player/Weapons/Effects/glacier_ground_visual.gd").new()
	visual.area = self
	add_child(visual)

func _apply_tick() -> void:
	var damage_length := get_damage_length()
	if damage_length <= 0.0:
		return
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	if not source_weapon.has_method("apply_glacier_trail_tick"):
		return
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(damage_length, path_width)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(global_rotation, to_global(Vector2(damage_length * 0.5, 0.0)))
	query.collision_mask = ENEMY_HURTBOX_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var seen_targets: Dictionary = {}
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var collider: Variant = hit.get("collider", null)
		if not collider is HurtBox:
			continue
		var target: Node = _resolve_hurtbox_target(collider as HurtBox)
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var apply_cold_snap: bool = cold_snap_active and not _cold_snap_target_ids.has(target_id)
		if bool(source_weapon.call("apply_glacier_trail_tick", target, apply_cold_snap)) and apply_cold_snap:
			_cold_snap_target_ids[target_id] = true

func _resolve_hurtbox_target(hurt_box: HurtBox) -> Node:
	var target: Node = null
	if hurt_box.has_method("get_damage_target"):
		target = hurt_box.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_owner()
	if target == null or not is_instance_valid(target):
		target = hurt_box.get_parent()
	return target
