extends Effect
class_name Fall

@export var speed: float = 400.0

@onready var p0 = Node2D.new()
@onready var p1 = Node2D.new()
@onready var p2 = Node2D.new()

var t = 0.0
var arrived = false
var destination : Vector2 = Vector2(400, 600)
var _helpers_added := false

func bullet_effect_ready() -> void:
	for child in bullet.get_children():
		if child is HitBox or child is HitBoxDot:
			child.set_collision_mask_value(3, false)
	p2.global_position = destination
	p1.global_position = Vector2(p2.global_position.x, p2.global_position.y - 600)
	p0.global_position = Vector2(p1.global_position.x - 400, p1.global_position.y)
	bullet.call_deferred("add_sibling",p0)
	bullet.call_deferred("add_sibling",p1)
	bullet.call_deferred("add_sibling",p2)
	_helpers_added = true

func _physics_process(delta: float) -> void:
	if arrived:
		return
	if bullet.global_position.distance_to(p2.global_position) > 5:
		t += delta * (speed / 200.0)
		bullet.global_position = _quadratic_bezier(t)
	else:
		arrived = true
		_cleanup_helpers()
		bullet.queue_free()

func _quadratic_bezier(t: float):
	var q0 = p0.global_position.lerp(p1.global_position, t)
	var q1 = p1.global_position.lerp(p2.global_position, t)
	var r = q0.lerp(q1, t)
	return r

func _exit_tree() -> void:
	_cleanup_helpers()

func _cleanup_helpers() -> void:
	if not _helpers_added:
		return
	for helper in [p0, p1, p2]:
		if helper and is_instance_valid(helper):
			helper.queue_free()
	_helpers_added = false
