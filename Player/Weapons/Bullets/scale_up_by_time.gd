extends Node2D

@onready var module_parent : BulletBase = self.get_parent() # Bullet root is parent
var sprite : Sprite2D

# This module applies after bullet created
func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return
	sprite = module_parent.bullet_sprite

func _physics_process(delta: float) -> void:
	if sprite and module_parent.bullet_sprite.scale.x < 3:
		module_parent.bullet_sprite.scale = Vector2(module_parent.bullet_sprite.scale * 1.01)
