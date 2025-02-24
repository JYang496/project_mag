extends Node2D

var t = 0.0
@export var drop : PackedScene
var arrived = false
var value : int
var drop_instance
@onready var p0 = $p0
@onready var p1 = $p1
@onready var p2 = $p2
func _ready() -> void:
	p2.position = get_random_position_in_circle()
	p1.position.x = (p0.position.x + p2.position.x) / 2
	p1.position.y = (p0.position.y + p2.position.y) / 2 - randf_range(80.0,140.0)

	drop_instance = drop.instantiate()
	if value:
		drop_instance.value = value
	self.call_deferred("add_sibling",drop_instance)
	drop_instance.position = $p0.position

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


func _quadratic_bezier(t: float):
	var q0 = $p0.global_position.lerp($p1.global_position, t)
	var q1 = $p1.global_position.lerp($p2.global_position, t)
	var r = q0.lerp(q1, t)
	return r
