extends Effect
class_name ExplosionEffect

var projectile_texture_resource = preload("res://Textures/test/bullet.png")
@onready var explosion = load("res://Player/Weapons/Projectiles/projectile.tscn")
@export var damage = 10
@export var explosion_size = 2.0
var oc_mode : bool = false

func projectile_effect_ready() -> void:
	projectile.tree_exiting.connect(_on_parent_exiting)
	projectile.tree_exited.connect(_on_parent_exited)	

func _on_parent_exiting() -> void:
	var spawn_projectile = explosion.instantiate()
	spawn_projectile.damage = damage
	spawn_projectile.hp = 99
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = explosion_size
	spawn_projectile.expire_time = 0.1
	var spawn_parent: Node = projectile.get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = projectile.get_tree().root
	spawn_parent.call_deferred("add_child", spawn_projectile)
	

func _on_parent_exited() -> void:
	pass
