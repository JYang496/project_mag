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
		apply_attack(area)

func apply_attack(area) -> void:
	var target = area.get_owner()
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if "damage_type" in hitbox_owner:
		damage_type = Attack.normalize_damage_type(hitbox_owner.damage_type)
	var knock_back_data := {
		"amount": 0,
		"angle": Vector2.ZERO
	}
	if "knock_back" in hitbox_owner:
		knock_back_data = hitbox_owner.knock_back
	var damage_data := DamageManager.build_damage_data(
		hitbox_owner,
		int(hitbox_owner.damage),
		damage_type,
		knock_back_data
	)
	# Guard duplicate enter/overlap events in the same short window.
	damage_data.dedupe_token = StringName("hitbox_once_%d_%d" % [get_instance_id(), target.get_instance_id()])
	damage_data.dedupe_window_sec = 0.02
	DamageManager.apply_to_target(target, damage_data)
	var owner_player := damage_data.source_player as Player
	if owner_player and is_instance_valid(owner_player):
		owner_player.apply_bonus_hit_if_needed(target)
	if hitbox_owner and hitbox_owner.has_method("on_hit_target"):
		hitbox_owner.on_hit_target(target)
	if hitbox_owner.has_method("enemy_hit"):
		hitbox_owner.enemy_hit(1)	

func _on_area_exited(_exited_area: Area2D) -> void:
	check_overlapping()

func check_overlapping() -> void:
	for area in get_overlapping_areas():
		if area is HurtBox:
			hitbox_owner.overlapping = true
		hitbox_owner.overlapping = false


