extends Node2D
class_name WeaponModules

@export_flags(
	"movement",
	"debuff",
	"buff",
	"dot",
	"duration",
	"range",
	"melee",
	"stacking",
	"trigger",
	"charge",
	"projectile",
	"summon",
	"physical",
	"energy",
	"explosive",
	"fire",
	"freeze"
) var weapon_traits: int = 0

func get_normalized_weapon_traits() -> Array[StringName]:
	return CombatTrait.flags_to_traits(weapon_traits)
