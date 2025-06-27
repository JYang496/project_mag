extends Area2D
class_name HitBox

@onready var collision = $CollisionShape2D
var hitbox_owner
var attack : Attack
var status_on_hit = {"erosion": {"time":5,"damage":1}}

func _ready() -> void:
	if hitbox_owner:
		set_owner(hitbox_owner)

# Set Mask to detect hurt boxes
func _on_area_entered(area):
	if area is HurtBox:
		hitbox_owner.overlapping = true
		apply_attack(area)

func apply_attack(area) -> void:
	var target = area.get_owner()
	apply_effect_on_target(target)
	attack = Attack.new()
	attack.damage = hitbox_owner.damage
	if "knock_back" in hitbox_owner:
		attack.knock_back = hitbox_owner.knock_back
	target.damaged(attack)
	if hitbox_owner.has_method("enemy_hit"):
		hitbox_owner.enemy_hit(1)	

func apply_effect_on_target(target) -> void:
	if target.get("status_list") != null:
		for status in status_on_hit:
			target.status_list.set(status,status_on_hit[status])

func _on_area_exited(_exited_area: Area2D) -> void:
	check_overlapping()

func check_overlapping() -> void:
	for area in get_overlapping_areas():
		if area is HurtBox:
			hitbox_owner.overlapping = true
		hitbox_owner.overlapping = false
