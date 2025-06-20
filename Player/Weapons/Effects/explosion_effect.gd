extends Effect
class_name ExplosionEffect

var bul_texture = preload("res://Textures/test/bullet.png")
@onready var explosion = load("res://Player/Weapons/Bullets/bullet.tscn")
@export var damage = 10
@export var explosion_size = 2.0
var oc_mode : bool = false

func bullet_effect_ready() -> void:
	bullet.tree_exiting.connect(_on_parent_exiting)
	bullet.tree_exited.connect(_on_parent_exited)	

func _on_parent_exiting() -> void:
	var spawn_bullet = explosion.instantiate()
	spawn_bullet.damage = damage
	spawn_bullet.hp = 99
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	spawn_bullet.size = explosion_size
	spawn_bullet.expire_time = 0.1
	bullet.get_tree().root.call_deferred("add_child",spawn_bullet)
	

func _on_parent_exited() -> void:
	pass
