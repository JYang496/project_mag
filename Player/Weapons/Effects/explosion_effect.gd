extends Node2D

@onready var module_parent = self.get_parent() # Bullet root is parent
var bul_texture = preload("res://Textures/test/bullet.png")
@onready var explosion = load("res://Player/Weapons/Bullets/bullet.tscn")
var damage = 10
var oc_mode : bool = false

func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return
	module_parent.tree_exiting.connect(_on_parent_exiting)
	module_parent.tree_exited.connect(_on_parent_exited)

func _on_parent_exiting() -> void:
	var spawn_bullet = explosion.instantiate()
	spawn_bullet.damage = damage
	spawn_bullet.hp = 99
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	spawn_bullet.expire_time = 0.1
	module_parent.get_tree().root.call_deferred("add_child",spawn_bullet)
	

func _on_parent_exited() -> void:
	pass
