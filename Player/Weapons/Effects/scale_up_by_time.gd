extends Effect
class_name ScaleUpByTime

var sprite : Sprite2D

# This module applies after bullet created
#func _ready() -> void:
	#bullet = self.get_parent()
	#if not bullet:
		#print("Error: module does not have owner")
		#return
	#sprite = projectile.projectile_sprite

func projectile_effect_ready() -> void:
	sprite = projectile.projectile_sprite

func _physics_process(delta: float) -> void:
	if sprite and projectile.projectile_sprite.scale.x < 3:
		projectile.projectile_sprite.scale = Vector2(projectile.projectile_sprite.scale * 1.01)
