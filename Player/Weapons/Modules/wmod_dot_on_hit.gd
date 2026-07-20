extends "res://Player/Weapons/Modules/wmod_on_hit_base.gd"
# Use on hit-capable weapons to apply stacking DOT damage over time.
class_name Erosion

var ITEM_NAME := "Erosion"

@export var base_tick: int = 5
@export var base_damage: int = 1
@export var tick_per_fuse: int = 0
@export var damage_per_fuse: int = 0

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("apply_status_effect"):
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var level_scale := get_effective_additive(1.0, 0.4)
	var tick: int = max(1, int(round(float(base_tick + tick_per_fuse * fuse_bonus_steps) * level_scale)))
	var damage: int = max(1, int(round(float(base_damage + damage_per_fuse * fuse_bonus_steps) * level_scale)))
	var owner_player := DamageManager.resolve_source_player(source_weapon)
	var effect: DotStatusEffect = DotStatusEffect.new().setup_dot_effect(
		tick,
		damage,
		Attack.TYPE_PHYSICAL,
		&"erosion_dot"
	)
	effect.set_source_context(owner_player, source_weapon)
	target.apply_status_effect(effect)
