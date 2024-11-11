extends Node2D

@onready var raycast = $RayCast2D
@onready var line = $RayCast2D/Line2D

var target_position : Vector2 = Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	raycast.target_position = target_position
	line.show()
	line.add_point(Vector2.ZERO)
	line.add_point(raycast.target_position)
	pass

func _physics_process(delta: float) -> void:
	pass

func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")
