extends "res://Player/Weapons/Modules/wmod_synergy_base.gd"

var ITEM_NAME := "Kill Endurance"
@export var refund_chance_lv1 := 0.35
@export var refund_chance_lv2 := 0.55
@export var refund_chance_lv3 := 0.75
@export var refund_amount := 1

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	var reason := super.get_incompatibility_reason(target_weapon)
	if reason != "":
		return reason
	return "" if target_weapon.uses_ammo_system() else "Requires an ammo-based weapon."

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not is_enemy_target(target) or not is_target_dead(target) or source_weapon == null or not source_weapon.uses_ammo_system():
		return
	if randf() > get_level_value(refund_chance_lv1, refund_chance_lv2, refund_chance_lv3):
		return
	source_weapon.current_ammo = mini(source_weapon.get_effective_magazine_capacity(), source_weapon.current_ammo + maxi(refund_amount, 1))
