extends CharacterBody2D

var level : int
var hp = 6
var damage = 2
var speed = 1200.0
var target = null
var direction = Vector2.ZERO
@onready var on_return = false
var on_land
var blt_texture

@onready var expire_timer = $ExpireTimer
@onready var player  = get_tree().get_first_node_in_group("player")

func _ready():
	if target == null:
		target = get_global_mouse_position()
	rotation = global_position.direction_to(target).angle() + deg_to_rad(90)
	$ReturnTimer.start()
		
func _physics_process(delta):
	var distance_to_target = global_position.distance_to(target)
	if on_return:
		target = player.global_position
		speed = 1200
	elif distance_to_target < 10: # Slow down the object while closing the target
		speed *= 0.5
	direction = global_position.direction_to(target).normalized()
	if abs(target.x - global_position.x) > 0.01 and abs(target.y - global_position.y) > 0.01:
		global_position = global_position.move_toward(target,delta * speed)
	
func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		queue_free()
		

func _on_return_timer_timeout():
	on_return = true
	target = player.global_position
	rotation = global_position.direction_to(target).angle() + deg_to_rad(90)


func _on_return_box_body_entered(body: Node2D) -> void:
	if body is Player and on_return:
		queue_free()
