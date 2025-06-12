extends Effect
class_name ScaleUpByTime

var sprite : Sprite2D

# This module applies after bullet created
#func _ready() -> void:
	#bullet = self.get_parent()
	#if not bullet:
		#print("Error: module does not have owner")
		#return
	#sprite = bullet.bullet_sprite

func bullet_effect_ready() -> void:
	sprite = bullet.bullet_sprite

func _physics_process(delta: float) -> void:
	if sprite and bullet.bullet_sprite.scale.x < 3:
		bullet.bullet_sprite.scale = Vector2(bullet.bullet_sprite.scale * 1.01)
