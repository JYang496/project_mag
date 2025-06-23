extends Area2D
class_name HitBox

@onready var collision = $CollisionShape2D
var hitbox_owner
var attack : Attack

func _ready() -> void:
	if hitbox_owner:
		set_owner(hitbox_owner)

# Set Mask to detect hurt boxes
func _on_area_entered(area):
	if area is HurtBox:
		hitbox_owner.overlapping = true
		var target = area.get_owner()
		attack = Attack.new()
		attack.damage = hitbox_owner.damage
		if "knock_back" in hitbox_owner:
			attack.knock_back = hitbox_owner.knock_back
		target.damaged(attack)
		if hitbox_owner.has_method("enemy_hit"):
			hitbox_owner.enemy_hit(1)

func _on_area_exited(_exited_area: Area2D) -> void:
	for area in get_overlapping_areas():
		if area is HurtBox:
			hitbox_owner.overlapping = true
			return
	hitbox_owner.overlapping = false
