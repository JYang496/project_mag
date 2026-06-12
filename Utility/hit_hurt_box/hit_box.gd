extends Area2D
class_name HitBox

@onready var collision = $CollisionShape2D
var hitbox_owner
var attack : Attack

const SPEAR_PIERCE_MARK_ID := &"spear_pierce"
const SPEAR_PIERCE_MARK_BONUS_MULTIPLIER_KEY := &"bonus_multiplier"
const SPEAR_PIERCE_MARK_THRESHOLD_KEY := &"threshold"

func _ready() -> void:
	if hitbox_owner:
		set_owner(hitbox_owner)

# Set Mask to detect hurt boxes
func _on_area_entered(area):
	if area is HurtBox:
		hitbox_owner.overlapping = true
		apply_attack(area)

func apply_attack(area) -> void:
	var target: Node = null
	if area is HurtBox and area.has_method("get_damage_target"):
		target = area.call("get_damage_target")
	if target == null or not is_instance_valid(target):
		target = area.get_owner()
	if target == null or not is_instance_valid(target):
		target = area.get_parent()
	if target == null or not is_instance_valid(target):
		return
	if hitbox_owner and hitbox_owner.has_method("can_hit_target"):
		if not bool(hitbox_owner.call("can_hit_target", target)):
			return
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if "damage_type" in hitbox_owner:
		damage_type = Attack.normalize_damage_type(hitbox_owner.damage_type)
	var knock_back_data := {
		"amount": 0,
		"angle": Vector2.ZERO
	}
	if "knock_back" in hitbox_owner:
		knock_back_data = hitbox_owner.knock_back
	var outgoing_damage := int(hitbox_owner.damage)
	if hitbox_owner and hitbox_owner.has_method("get_runtime_damage_value"):
		var base_damage_variant: Variant = hitbox_owner.get("base_damage")
		if base_damage_variant != null:
			outgoing_damage = int(hitbox_owner.call("get_runtime_damage_value", float(base_damage_variant)))
	outgoing_damage = _apply_spear_pierce_mark_bonus(target, outgoing_damage)
	var damage_data := DamageManager.build_damage_data(
		hitbox_owner,
		max(1, outgoing_damage),
		damage_type,
		knock_back_data,
		DamageData.SOURCE_PLAYER_WEAPON if _resolve_source_weapon() != null else StringName(),
		_resolve_delivery_type()
	)
	# Guard duplicate enter/overlap events in the same short window.
	damage_data.dedupe_token = StringName("hitbox_once_%d_%d" % [get_instance_id(), target.get_instance_id()])
	damage_data.dedupe_window_sec = 0.02
	var damage_result: DamageResult
	if area is HurtBox:
		damage_result = DamageManager.apply_to_hurt_box_result(area, damage_data)
	else:
		damage_result = DamageManager.apply_to_target_result(target, damage_data)
	if hitbox_owner and damage_result.applied and hitbox_owner.has_method("on_hit_target_damage_dealt"):
		hitbox_owner.call("on_hit_target_damage_dealt", target, damage_type, damage_result.final_damage)
	var owner_player := damage_data.source_player as Player
	if owner_player and is_instance_valid(owner_player):
		owner_player.apply_bonus_hit_if_needed(target)
	if hitbox_owner and hitbox_owner.has_method("on_hit_target_with_damage_type"):
		hitbox_owner.call("on_hit_target_with_damage_type", target, damage_type)
	elif hitbox_owner and hitbox_owner.has_method("on_hit_target"):
		hitbox_owner.on_hit_target(target)
	if hitbox_owner.has_method("consume_projectile_durability"):
		hitbox_owner.call("consume_projectile_durability", 1, target)
	elif hitbox_owner.has_method("enemy_hit"):
		hitbox_owner.enemy_hit(1)

func _resolve_source_weapon() -> Weapon:
	if hitbox_owner is Weapon:
		return hitbox_owner as Weapon
	if hitbox_owner != null and hitbox_owner.get("source_weapon") is Weapon:
		return hitbox_owner.get("source_weapon") as Weapon
	return null

func _resolve_delivery_type() -> StringName:
	if hitbox_owner is Projectile:
		return DamageDeliveryType.PROJECTILE
	if hitbox_owner is Weapon:
		return DamageDeliveryType.MELEE_CONTACT
	if hitbox_owner != null and hitbox_owner.get("beam_profile") != null:
		return DamageDeliveryType.BEAM
	return StringName()

func _apply_spear_pierce_mark_bonus(target: Node, damage_value: int) -> int:
	if target == null or not is_instance_valid(target):
		return damage_value
	if hitbox_owner == null or not is_instance_valid(hitbox_owner):
		return damage_value
	if not hitbox_owner.has_method("get_projectile_pierce_capacity"):
		return damage_value
	if not target.has_method("has_mark") or not bool(target.call("has_mark", SPEAR_PIERCE_MARK_ID)):
		return damage_value
	var pierce_capacity := int(hitbox_owner.call("get_projectile_pierce_capacity"))
	var threshold := int(target.call("get_mark_value", SPEAR_PIERCE_MARK_ID, SPEAR_PIERCE_MARK_THRESHOLD_KEY, 4))
	if pierce_capacity < threshold:
		return damage_value
	var multiplier := maxf(float(target.call("get_mark_value", SPEAR_PIERCE_MARK_ID, SPEAR_PIERCE_MARK_BONUS_MULTIPLIER_KEY, 1.35)), 1.0)
	return max(1, int(round(float(damage_value) * multiplier)))

func _on_area_exited(_exited_area: Area2D) -> void:
	check_overlapping()

func check_overlapping() -> void:
	for area in get_overlapping_areas():
		if area is HurtBox:
			hitbox_owner.overlapping = true
		hitbox_owner.overlapping = false
