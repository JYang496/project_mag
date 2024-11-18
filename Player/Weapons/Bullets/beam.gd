extends Node2D

@onready var raycast = $RayCast2D
@onready var line = $RayCast2D/Line2D
@onready var expire_timer = $ExpireTimer

var target_position : Vector2 = Vector2.ZERO

var attack : Attack
var damage = 1

var frame_counter = 0
var frames_until_show = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	raycast.target_position = 42 * target_position

func _physics_process(delta: float) -> void:
	frame_counter += 1
	if frame_counter > frames_until_show:
		line.show()
	if raycast.is_colliding():
		var collision_point = raycast.get_collision_point()
		var collider = raycast.get_collider()

		line.points = [Vector2.ZERO, to_local(collision_point)]
		if collider is HurtBox:
			var target = collider.get_owner()
			attack = Attack.new()
			attack.damage = damage
			target.damaged(attack)
	else:
		line.points = [Vector2.ZERO, to_local(raycast.target_position)]

func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")
