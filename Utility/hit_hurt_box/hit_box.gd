extends Area2D
class_name HitBox

@onready var collision = get_node("CollisionShape2D")
@onready var hit_box_owner = get_owner()
var hitbox_owner
var attack : Attack

func _ready() -> void:
	if hitbox_owner:
		set_owner(hitbox_owner)
		hit_box_owner = get_owner()

# Set Mask to detect hurt boxes
func _on_area_entered(area):
	if area is HurtBox:
		var target = area.get_owner()
		attack = Attack.new()
		attack.damage = hit_box_owner.damage
		if "knock_back" in hitbox_owner:
			attack.knock_back = hit_box_owner.knock_back
		target.damaged(attack)
		if hit_box_owner.has_method("enemy_hit"):
			hit_box_owner.enemy_hit(1)
