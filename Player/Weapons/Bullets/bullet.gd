extends Node2D
class_name BulletBase

var hp = 1
var damage = 1
var expire_time = 2.5
var base_displacement = Vector2.ZERO
var bullet_displacement = Vector2.ZERO
var blt_texture
var module_list = []

# Signals
signal enemy_hit_signal

@onready var player  = get_tree().get_first_node_in_group("player")
@onready var expire_timer = $ExpireTimer
@onready var bullet = $Bullet
@onready var bullet_sprite = $Bullet/BulletSprite
@onready var hitbox_collision = $Bullet/BulletSprite/HitBox/CollisionShape2D

func _ready() -> void:
	expire_timer.wait_time = expire_time
	bullet_sprite.texture = blt_texture
	edit_hitbox_shape()
	expire_timer.start()

# This function will adjust the hitbox shape identical to your sprite size
func edit_hitbox_shape() -> void:
	var shape = RectangleShape2D.new()
	shape.size = bullet_sprite.texture.get_size()
	hitbox_collision.shape = shape


func enable_linear(direction : Vector2 = Vector2.UP, speed : float = 100.0) -> void:
	print(self,"do not use this function!")
	var linear_movement = load("res://Player/Weapons/Bullets/linear_movement.tscn")
	var linear_movement_ins = linear_movement.instantiate()
	linear_movement_ins.direction = direction
	linear_movement_ins.speed = speed
	add_child(linear_movement_ins)

func enable_spiral(spin_rate : float = PI, spin_speed : float = 100.0) -> void:
	print(self,"do not use this function!")
	var spiral_movement = load("res://Player/Weapons/Bullets/spiral_movement.tscn")
	var spiral_movement_ins = spiral_movement.instantiate()
	spiral_movement_ins.spin_rate = spin_rate
	spiral_movement_ins.spin_speed = spin_speed
	add_child(spiral_movement_ins)	


func _physics_process(delta: float) -> void:
	self.position = self.position + base_displacement * delta
	self.rotation = base_displacement.angle() + deg_to_rad(90)
	bullet.position = bullet.position + bullet_displacement * delta

func enemy_hit(charge = 1):
	hp -= charge
	enemy_hit_signal.emit()
	if hp <= 0:
		self.call_deferred("queue_free")



func _on_expire_timer_timeout() -> void:
	self.call_deferred("queue_free")
