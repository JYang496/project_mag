extends WeaponBranchBehavior
class_name CannonZeroBranch

const ZERO_CANNON_TEXTURE: Texture2D = preload("res://asset/images/weapons/cannon3.png")

func on_weapon_ready() -> void:
	_apply_zero_cannon_visual()

func on_level_applied(_level: int) -> void:
	_apply_zero_cannon_visual()

func on_removed() -> void:
	super.on_removed()
	if weapon != null and is_instance_valid(weapon):
		weapon.call("_apply_fuse_sprite")

func _apply_zero_cannon_visual() -> void:
	if weapon == null or not is_instance_valid(weapon) or weapon.sprite == null:
		return
	weapon.sprite.texture = ZERO_CANNON_TEXTURE

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_suppressed_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.PHYSICAL]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 10.0

func get_energy_release_bonus_at_full() -> float:
	return 1.50

func get_energy_full_fire_passive_id() -> StringName:
	return &"cannon_zero_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Zero Burst"
