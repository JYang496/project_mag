extends Node2D

@export var hitbox_dot : HitBoxDot
@export var hitbox_collision_shape : CollisionShape2D
@export var line2d : Line2D

var damage = 1
var target_position
var width
var hit_cd

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if hitbox_dot:
		var points = line2d.points
		var start = points[0]
		var end = points[1]
		var length = start.distance_to(end)
		var direction = (end - start).normalized()
		
		var rect_shape  = RectangleShape2D.new()
		rect_shape.extents = Vector2(length / 2, 2) # Half length and width
		hitbox_collision_shape.shape = rect_shape
		
		hitbox_dot.position = start + direction * length / 2
		hitbox_dot.rotation = direction.angle()
