extends Node2D
class_name Module

# Weapon -> Modules -> Module
const MAX_LEVEL: int = 3

var weapon: Weapon
@export var cost : int
@onready var sprite: Sprite2D = get_node_or_null("%Sprite") as Sprite2D
@export var supports_melee: bool = true
@export var supports_ranged: bool = true
@export_range(1, MAX_LEVEL, 1) var module_level: int = 1
@export var module_traits: PackedStringArray = []
@export var stat_multipliers: Dictionary = {}
@export var stat_additives: Dictionary = {}
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
	"area_of_effect",
	"fire",
	"freeze",
	"heat"
) var required_weapon_traits: int = 0

func _enter_tree() -> void:
	weapon = _resolve_weapon()
	call_deferred("_validate_weapon_compatibility")

func _ready() -> void:
	if weapon == null:
		weapon = _resolve_weapon()

func can_apply_to_weapon(target_weapon: Weapon) -> bool:
	return get_incompatibility_reason(target_weapon) == ""

func get_incompatibility_reason(target_weapon: Weapon) -> String:
	if not target_weapon:
		return "Invalid weapon."
	if target_weapon.has_method("supports_melee_contact") and target_weapon.supports_melee_contact():
		if not supports_melee:
			return "Not compatible with melee weapons."
	if target_weapon.has_method("supports_projectiles") and target_weapon.supports_projectiles():
		if not supports_ranged:
			return "Not compatible with ranged weapons."
	var required_traits := get_normalized_required_weapon_traits()
	if target_weapon.has_method("has_any_explicit_weapon_traits"):
		if not target_weapon.has_any_explicit_weapon_traits(required_traits):
			var trait_names: PackedStringArray = []
			for required_trait_name in required_traits:
				trait_names.append(str(required_trait_name))
			if trait_names.is_empty():
				return "Weapon does not match required traits."
			return "Requires one of: %s" % ", ".join(trait_names)
	elif target_weapon.has_method("has_any_weapon_traits"):
		if not target_weapon.has_any_weapon_traits(required_traits):
			var trait_names: PackedStringArray = []
			for required_trait_name in required_traits:
				trait_names.append(str(required_trait_name))
			if trait_names.is_empty():
				return "Weapon does not match required traits."
			return "Requires one of: %s" % ", ".join(trait_names)
	return ""

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

func _validate_weapon_compatibility() -> void:
	weapon = _resolve_weapon()
	if weapon == null:
		return
	if can_apply_to_weapon(weapon):
		return
	push_warning(
		"Module '%s' is incompatible with weapon '%s'; removing module." %
		[name, weapon.name]
	)
	queue_free()

func set_module_level(new_level: int) -> void:
	module_level = clampi(new_level, 1, MAX_LEVEL)

func increase_module_level(steps: int = 1) -> bool:
	var previous_level := module_level
	set_module_level(module_level + max(steps, 0))
	return module_level > previous_level

func get_module_display_name() -> String:
	var item_name: Variant = get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		return str(item_name)
	return name

func get_effective_multiplier(base_multiplier: float, per_level_bonus: float = 0.35) -> float:
	var level_scale := 1.0 + per_level_bonus * float(max(0, module_level - 1))
	if base_multiplier >= 1.0:
		return 1.0 + (base_multiplier - 1.0) * level_scale
	return maxf(0.05, 1.0 - (1.0 - base_multiplier) * level_scale)

func get_effective_additive(base_value: float, per_level_bonus: float = 0.5) -> float:
	var level_scale := 1.0 + per_level_bonus * float(max(0, module_level - 1))
	return base_value * level_scale

func configure_stat_modifiers() -> void:
	pass

func apply_stat_modifiers(stat_block: Dictionary) -> Dictionary:
	if stat_block == null:
		return {}
	configure_stat_modifiers()
	var output: Dictionary = stat_block.duplicate(true)
	for key_variant in stat_additives.keys():
		var key := str(key_variant)
		if not output.has(key):
			continue
		var base_add := float(stat_additives[key_variant])
		var final_add := get_effective_additive(base_add)
		output[key] = float(output[key]) + final_add
	for key_variant in stat_multipliers.keys():
		var key := str(key_variant)
		if not output.has(key):
			continue
		var base_multiplier := float(stat_multipliers[key_variant])
		var final_multiplier := get_effective_multiplier(base_multiplier)
		output[key] = float(output[key]) * final_multiplier
	return output

func get_effect_descriptions() -> PackedStringArray:
	configure_stat_modifiers()
	var descriptions: PackedStringArray = []
	for key_variant in stat_multipliers.keys():
		var key := str(key_variant)
		var raw_multiplier: float = float(stat_multipliers[key_variant])
		var final_multiplier: float = get_effective_multiplier(raw_multiplier)
		var delta_percent := (final_multiplier - 1.0) * 100.0
		var sign := "+" if delta_percent >= 0.0 else ""
		descriptions.append("%s %s%.0f%%" % [_format_stat_label(key), sign, delta_percent])
	for key_variant in stat_additives.keys():
		var key := str(key_variant)
		var raw_add: float = float(stat_additives[key_variant])
		var final_add: float = get_effective_additive(raw_add)
		var sign := "+" if final_add >= 0.0 else ""
		descriptions.append("%s %s%.1f" % [_format_stat_label(key), sign, final_add])
	return descriptions

func _format_stat_label(stat_key: String) -> String:
	var pretty := stat_key.replace("_", " ")
	return pretty.capitalize()
