extends Node2D

var t = 0.0
@export var drop : PackedScene
@export var spawn_global_position := Vector2.ZERO
var item_id
var level
var module_scene: PackedScene
var module_level: int = 1
var resolve_immediately: bool = false
var arrived = false
var value : int
var drop_instance
@onready var p0 = $p0
@onready var p1 = $p1
@onready var p2 = $p2
func _ready() -> void:
	global_position = spawn_global_position
	p2.position = get_random_position_in_circle()
	if resolve_immediately:
		p2.position = get_random_position_in_ring(90.0, 160.0)
	p1.position.x = (p0.position.x + p2.position.x) / 2
	p1.position.y = (p0.position.y + p2.position.y) / 2 - randf_range(80.0,140.0)

	drop_instance = drop.instantiate()
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
	if resolve_immediately:
		_mark_drop_instance_spawn_ready(drop_instance)
		call_deferred("_attach_drop_instance_immediate")
		return
	call_deferred("_attach_drop_instance")

func _attach_drop_instance() -> void:
	if drop_instance == null or not is_instance_valid(self):
		return
	add_sibling(drop_instance)
	drop_instance.global_position = p0.global_position

func _attach_drop_instance_immediate() -> void:
	if drop_instance == null or not is_instance_valid(self):
		return
	add_sibling(drop_instance)
	drop_instance.global_position = p2.global_position
	queue_free()

func _mark_drop_instance_spawn_ready(instance: Node) -> void:
	if instance == null:
		return
	for property_info in instance.get_property_list():
		if str(property_info.get("name", "")) == "spawn_ready":
			instance.set("spawn_ready", true)
			return

func _physics_process(delta):
	if not drop_instance or arrived:
		return
	if drop_instance.global_position.distance_to($p2.global_position) > 5:
		t += delta
		drop_instance.global_position = _quadratic_bezier(t)
	else:
		arrived = true
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
	var q0 = $p0.global_position.lerp($p1.global_position, t)
	var q1 = $p1.global_position.lerp($p2.global_position, t)
	var r = q0.lerp(q1, time)
	return r
