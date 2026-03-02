extends Area2D
class_name HitBox

@onready var collision = $CollisionShape2D
var hitbox_owner
var attack : Attack
var status_on_hit = {}

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
	attack.damage = int(hitbox_owner.damage)
	var owner_player: Player = _resolve_owner_player(hitbox_owner)
	if owner_player and is_instance_valid(owner_player):
		attack.damage = owner_player.compute_outgoing_damage(attack.damage)
	if "knock_back" in hitbox_owner:
		attack.knock_back = hitbox_owner.knock_back
	target.damaged(attack)
	if owner_player and is_instance_valid(owner_player):
		owner_player.apply_bonus_hit_if_needed(target)
	if hitbox_owner and hitbox_owner.has_method("on_hit_target"):
		hitbox_owner.on_hit_target(target)
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

func _resolve_owner_player(node: Node) -> Player:
	if node == null:
		return null
	var current: Node = node
	while current:
		if current is Player:
			return current as Player
		current = current.get_parent()
	var source_weapon_value: Variant = node.get("source_weapon")
	if source_weapon_value != null and source_weapon_value is Node:
		var source_weapon: Node = source_weapon_value
		if source_weapon:
			current = source_weapon
			while current:
				if current is Player:
					return current as Player
				current = current.get_parent()
	return null
