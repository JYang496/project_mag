extends Node2D

@onready var raycast = $RayCast2D
@onready var line = $RayCast2D/Line2D

var target_position : Vector2 = Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raycast.target_position = target_position
	line.show()
	print(raycast.target_position)
	pass

func _physics_process(delta: float) -> void:
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var collider = raycast.get_collider()
		line.points = [Vector2.ZERO, to_local(collision_point)]
		print(line.points)
	pass

func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")
