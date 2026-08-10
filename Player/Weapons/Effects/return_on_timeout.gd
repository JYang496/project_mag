extends Effect
class_name ReturnOnTimeout

const MIN_TIMER_DURATION_SEC := 0.01

@onready var hitbox_once = preload("res://Combat/collision/hit_box.tscn")

@onready var return_timer: Timer = $ReturnTimer
@onready var stop_timer: Timer = $StopTimer
@onready var return_hitbox: Area2D = $ReturnHitbox
@onready var return_shape: CollisionShape2D = $ReturnHitbox/ReturnShape


var destination : Vector2
var return_time : float = 1.0
var stop_time : float = 0.5

var is_return : bool = false
var is_stopped : bool = false

var saved_displacement := Vector2.ZERO
var return_speed := 0.0


func projectile_effect_ready() -> void:
	stop_timer.wait_time = maxf(stop_time, MIN_TIMER_DURATION_SEC)
	stop_timer.start()	

func _physics_process(delta: float) -> void:
	if not is_return or projectile == null or not is_instance_valid(projectile):
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	var return_direction := projectile.global_position.direction_to(player.global_position)
	projectile.base_displacement = return_direction * return_speed

func _on_return_timer_timeout() -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	is_return = true
	create_return_hitbox()

func create_return_hitbox() -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if projectile.projectile_sprite == null or projectile.projectile_sprite.texture == null:
		return
	var shape = RectangleShape2D.new()
	shape.size = projectile.projectile_sprite.texture.get_size()
	return_shape.shape = shape

func _on_stop_timer_timeout() -> void:
	if not _capture_and_stop_projectile():
		return
	is_stopped = true
	return_timer.wait_time = maxf(return_time, MIN_TIMER_DURATION_SEC)
	return_timer.start()


func _capture_and_stop_projectile() -> bool:
	if projectile == null or not is_instance_valid(projectile):
		return false
	saved_displacement = projectile.base_displacement
	return_speed = saved_displacement.length()
	projectile.base_displacement = Vector2.ZERO
	return true


func _on_return_hitbox_body_entered(body: Node2D) -> void:
	projectile.call_deferred("queue_free")
