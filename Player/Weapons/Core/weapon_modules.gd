extends Node2D
class_name WeaponModules

@export_flags(
	"physical",
	"energy",
	"fire",
	"freeze",
	"heat",
	"charge"
) var weapon_traits: int = 0

func get_normalized_weapon_traits() -> Array[StringName]:
	return WeaponTrait.flags_to_traits(weapon_traits)
