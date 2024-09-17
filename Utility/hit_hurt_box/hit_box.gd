extends Area2D
class_name HitBox

@onready var collision = $CollisionShape2D
@onready var hit_box_owner = get_owner()
var attack : Attack

# Set Mask to detect hurt boxes
func _on_area_entered(area):
	if area is HurtBox:
		var target = area.get_owner()
		attack = Attack.new()
		attack.damage = hit_box_owner.damage
		if hit_box_owner.has_meta("knock_back"):
			attack.knock_back["angel"] = hit_box_owner.knock_back["angel"]
			attack.knock_back["amount"] = hit_box_owner.knock_back["amount"]
		target.damaged(attack)
		if hit_box_owner.has_method("enemy_hit"):
			hit_box_owner.enemy_hit(1)
