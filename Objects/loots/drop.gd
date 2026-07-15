extends Node2D

signal flight_started
signal flight_finished

@export var drop : PackedScene
@export var spawn_global_position := Vector2.ZERO
@export_range(0.1, 5.0, 0.05) var flight_duration: float = 1.0
@export_range(0.0, 12.0, 0.25) var flight_rotations: float = 5.0
var item_id
var level
var module_scene: PackedScene
var module_level: int = 1
var resolve_immediately: bool = false
var auto_collect_on_landing: bool = false
var settle_unclaimed_on_battle_start: bool = false
var value : int
var drop_instance
var _trajectory_height: float = 0.0
@onready var p0 = $p0
@onready var p1 = $p1
@onready var p2 = $p2

func _ready() -> void:
	global_position = spawn_global_position
	drop_instance = drop.instantiate()
	var drop_at_origin := drop_instance is Coin
	if drop_at_origin:
		p2.position = Vector2.ZERO
	elif auto_collect_on_landing or resolve_immediately:
		p2.position = get_random_position_in_ring(90.0, 160.0)
	else:
		p2.position = get_random_position_in_circle()
	_trajectory_height = randf_range(120.0, 180.0)
	p1.position = (p0.position + p2.position) * 0.5
	if not drop_instance.has_method("set_trajectory_screen_height"):
		p1.position.y -= _trajectory_height
	if module_scene:
		drop_instance.module_scene = module_scene
		drop_instance.module_level = module_level
	elif item_id and level:
		# Drop is an tiem
		drop_instance.item_id = item_id
		drop_instance.level = level
	elif value:
		# Drop is a coin
		drop_instance.value = value
	if auto_collect_on_landing:
		drop_instance.auto_collect_on_landing = true
	if settle_unclaimed_on_battle_start:
		drop_instance.settle_unclaimed_on_battle_start = true
	_set_optional_property(drop_instance, "trajectory_animation_managed", true)
	if resolve_immediately or drop_at_origin:
		_mark_drop_instance_spawn_ready(drop_instance)
		call_deferred("_attach_drop_instance_immediate")
		return
	call_deferred("_attach_drop_instance")

func _attach_drop_instance() -> void:
	if drop_instance == null or not is_instance_valid(self):
		return
	add_sibling(drop_instance)
	_set_drop_global_position(p0.global_position)
	_start_flight_animation()

func _attach_drop_instance_immediate() -> void:
	if drop_instance == null or not is_instance_valid(self):
		return
	add_sibling(drop_instance)
	_set_drop_global_position(p2.global_position)
	queue_free()

func _mark_drop_instance_spawn_ready(instance: Node) -> void:
	_set_optional_property(instance, "spawn_ready", true)

func _set_optional_property(instance: Node, property_name: String, property_value: Variant) -> void:
	if instance == null:
		return
	for property_info in instance.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			instance.set(property_name, property_value)
			return

func _start_flight_animation() -> void:
	if drop_instance == null or not is_instance_valid(drop_instance):
		return
	var duration := maxf(flight_duration, 0.1)
	var start_rotation := float(drop_instance.rotation)
	var tween := create_tween()
	flight_started.emit()
	if drop_instance.has_method("start_drop_flip"):
		drop_instance.call("start_drop_flip")
	tween.tween_method(_set_flight_progress, 0.0, 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		drop_instance,
		"rotation",
		start_rotation + TAU * flight_rotations,
		duration
	).set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_on_flight_animation_finished)

func _set_flight_progress(progress: float) -> void:
	if drop_instance == null or not is_instance_valid(drop_instance):
		return
	var eased_progress := clampf(progress, 0.0, 1.0)
	_set_trajectory_screen_height(4.0 * _trajectory_height * eased_progress * (1.0 - eased_progress))
	_set_drop_global_position(_quadratic_bezier(eased_progress))

func _set_trajectory_screen_height(height: float) -> void:
	if drop_instance.has_method("set_trajectory_screen_height"):
		drop_instance.call("set_trajectory_screen_height", height)

func _set_drop_global_position(target_position: Vector2) -> void:
	drop_instance.global_position = target_position
	if drop_instance.has_method("sync_trajectory_visual"):
		drop_instance.call("sync_trajectory_visual")

func _on_flight_animation_finished() -> void:
	if drop_instance and is_instance_valid(drop_instance):
		_set_trajectory_screen_height(0.0)
		_set_drop_global_position(p2.global_position)
		if drop_instance.has_method("activate_pickup_detection"):
			drop_instance.call("activate_pickup_detection")
	flight_finished.emit()
	if auto_collect_on_landing and drop_instance and is_instance_valid(drop_instance) \
			and drop_instance.has_method("collect_automatically"):
		drop_instance.call("collect_automatically")
	queue_free()

func get_random_position_in_circle(radius: float = 50.0) -> Vector2:
	var angle = randf_range(0, TAU)  # TAU is 2*PI in Godot
	var distance = randf_range(0.2,1.0) * radius  # Random distance between 0 and radius
	var x = cos(angle) * distance
	var y = sin(angle) * distance
	return Vector2(x, y)

func get_random_position_in_ring(min_radius: float, max_radius: float) -> Vector2:
	var safe_min := maxf(0.0, min_radius)
	var safe_max := maxf(max_radius, safe_min + 0.1)
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(safe_min, safe_max)
	return Vector2(cos(angle), sin(angle)) * distance


func _quadratic_bezier(time: float):
	var q0 = $p0.global_position.lerp($p1.global_position, time)
	var q1 = $p1.global_position.lerp($p2.global_position, time)
	var r = q0.lerp(q1, time)
	return r
