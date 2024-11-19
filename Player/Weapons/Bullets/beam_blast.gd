extends Node2D

@onready var hitbox_dot : HitBoxDot = $HitBoxDot
@onready var hitbox_collision_shape : CollisionShape2D = $HitBoxDot/CollisionShape2D
@onready var line2d : Line2D = $Line2D
@onready var expire_timer : Timer = $ExpireTimer
var damage = 1
var target_position = Vector2(100,100)
var width
var hit_cd

var frame_counter = 0
var frames_until_show = 1

func _ready() -> void:
	expire_timer.start()

func _physics_process(delta: float) -> void:
	frame_counter += 1
	if frame_counter > frames_until_show:
		line2d.show()
	if hitbox_dot:
		line2d.points = [Vector2.ZERO, 9 * target_position]
		var points = line2d.points
		var start = points[0]
		var end = points[1]
		var length = start.distance_to(end)
		var direction = (end - start).normalized()
		
		# Hitbox
		var rect_shape  = RectangleShape2D.new()
		rect_shape.extents = Vector2(length / 2, 2) # Half length and width
		hitbox_collision_shape.shape = rect_shape
		
		hitbox_dot.position = start + direction * length / 2
		hitbox_dot.rotation = direction.angle()


func _on_expire_timer_timeout() -> void:
	queue_free()
