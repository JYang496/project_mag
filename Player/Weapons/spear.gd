extends CharacterBody2D

var level : int
var hp = 6
var damage = 2
var speed = 1200.0
var direction = Vector2.ZERO
var destination : Vector2
@onready var on_return = false
var on_land
var blt_texture

@onready var expire_timer = $ExpireTimer
@onready var player  = get_tree().get_first_node_in_group("player")

func _ready():
	if destination == null:
		destination = get_global_mouse_position()
	rotation = global_position.direction_to(destination).angle() + deg_to_rad(90)
	$ReturnTimer.start()
		
func _physics_process(delta):
	var distance_to_target = global_position.distance_to(destination)
	if on_return:
		destination = player.global_position
		speed = 1200
	elif distance_to_target < 10: # Slow down the object while closing the target
		speed *= 0.5
	direction = global_position.direction_to(destination).normalized()
	if abs(destination.x - global_position.x) > 0.01 and abs(destination.y - global_position.y) > 0.01:
		global_position = global_position.move_toward(destination,delta * speed)
	
func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		queue_free()
		

func _on_return_timer_timeout():
	on_return = true
	destination = player.global_position
	rotation = global_position.direction_to(destination).angle() + deg_to_rad(90)


func _on_return_box_body_entered(body: Node2D) -> void:
	if body is Player and on_return:
		queue_free()
