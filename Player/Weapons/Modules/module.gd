extends Node2D
class_name Module

# Weapon -> Modules -> Module
var weapon: Weapon
@export var cost : int
@onready var sprite: Sprite2D = %Sprite
@export var supports_melee: bool = true
@export var supports_ranged: bool = true
@export var module_traits: PackedStringArray = []
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
) var required_weapon_traits: int = 0

func _ready() -> void:
	weapon = _resolve_weapon()
	if weapon and not can_apply_to_weapon(weapon):
		push_warning(
			"Module '%s' is incompatible with weapon '%s'; removing module." %
			[name, weapon.name]
		)
		call_deferred("queue_free")

func can_apply_to_weapon(target_weapon: Weapon) -> bool:
	if not target_weapon:
		return false
	if target_weapon.has_method("supports_melee_contact") and target_weapon.supports_melee_contact():
		if not supports_melee:
			return false
	if target_weapon.has_method("supports_projectiles") and target_weapon.supports_projectiles():
		if not supports_ranged:
			return false
	var required_traits := get_normalized_required_weapon_traits()
	if target_weapon.has_method("has_any_weapon_traits"):
		if not target_weapon.has_any_weapon_traits(required_traits):
			return false
	return true

func register_as_on_hit_plugin() -> void:
	weapon = _resolve_weapon()
	if weapon and can_apply_to_weapon(weapon) and weapon.has_method("register_on_hit_plugin"):
		weapon.register_on_hit_plugin(self)

func unregister_as_on_hit_plugin() -> void:
	weapon = _resolve_weapon()
	if weapon and weapon.has_method("unregister_on_hit_plugin"):
		weapon.unregister_on_hit_plugin(self)

func get_normalized_module_traits() -> Array[StringName]:
	return CombatTrait.normalize_array(module_traits)

func get_normalized_required_weapon_traits() -> Array[StringName]:
	return CombatTrait.flags_to_traits(required_weapon_traits)

func _resolve_weapon() -> Weapon:
	var current: Node = get_parent()
	while current:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null
