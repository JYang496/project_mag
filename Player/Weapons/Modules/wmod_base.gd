extends Node2D
class_name Module

# Weapon -> Modules -> Module
const RARITY_UTIL := preload("res://data/LootRarity.gd")
const MAX_LEVEL: int = 3

var weapon: Weapon
@export var cost : int
@onready var sprite: Sprite2D = get_node_or_null("%Sprite") as Sprite2D
@export_range(1, MAX_LEVEL, 1) var module_level: int = 1
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export_range(0.0, 1000000.0, 0.01) var drop_weight: float = 100.0
@export var module_tags: PackedStringArray = []
@export var level_effects: PackedStringArray = []
@export var stat_multipliers: Dictionary = {}
@export var stat_additives: Dictionary = {}
@export_flags(
	"physical",
	"energy",
	"fire",
	"freeze",
	"heat",
	"charge"
) var required_weapon_traits: int = 0
@export_flags("projectile", "melee_contact", "beam", "area") var required_delivery_types: int = 0
@export_flags("summon", "trap", "support", "movement") var required_weapon_capabilities: int = 0
@export_flags(
	"projectile_spawn",
	"hit",
	"damage_dealt",
	"area_damage",
	"beam_hit",
	"reload_start",
	"reload_duration",
	"kill"
) var required_hooks: int = 0

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
	var required_delivery := get_normalized_required_delivery_types()
	if not required_delivery.is_empty() and target_weapon.has_method("has_delivery_type"):
		var matched_delivery := false
		for delivery_type in required_delivery:
			if target_weapon.has_delivery_type(delivery_type):
				matched_delivery = true
				break
		if not matched_delivery:
			var delivery_names: PackedStringArray = []
			for required_delivery_type in required_delivery:
				delivery_names.append(str(required_delivery_type))
			return "Requires delivery type: %s" % ", ".join(delivery_names)
	var required_traits := get_normalized_required_weapon_traits()
	if target_weapon.has_method("has_any_weapon_traits"):
		if not target_weapon.has_any_weapon_traits(required_traits):
			var trait_names: PackedStringArray = []
			for required_trait_name in required_traits:
				trait_names.append(str(required_trait_name))
			if trait_names.is_empty():
				return "Weapon does not match required traits."
			return "Requires one of: %s" % ", ".join(trait_names)
	var required_capabilities := get_normalized_required_weapon_capabilities()
	if not required_capabilities.is_empty():
		if not target_weapon.has_method("has_any_weapon_capabilities") \
				or not target_weapon.has_any_weapon_capabilities(required_capabilities):
			return "Requires one of capabilities: %s" % ", ".join(PackedStringArray(required_capabilities))
	var hook_reason := get_hook_validation_error()
	if hook_reason != "":
		return hook_reason
	return ""

func register_as_on_hit_plugin() -> void:
	weapon = _resolve_weapon()
	if weapon and can_apply_to_weapon(weapon) and weapon.has_method("register_on_hit_plugin"):
		weapon.register_on_hit_plugin(self)

func unregister_as_on_hit_plugin() -> void:
	weapon = _resolve_weapon()
	if weapon and weapon.has_method("unregister_on_hit_plugin"):
		weapon.unregister_on_hit_plugin(self)

func get_normalized_module_tags() -> Array[StringName]:
	return ModuleTag.normalize_array(module_tags)

func get_unknown_module_tags() -> Array[StringName]:
	var output: Array[StringName] = []
	for tag in get_normalized_module_tags():
		if not ModuleTag.CORE.has(tag):
			output.append(tag)
	return output

func get_normalized_required_weapon_traits() -> Array[StringName]:
	return WeaponTrait.flags_to_traits(required_weapon_traits)

func get_normalized_required_delivery_types() -> Array[StringName]:
	return DamageDeliveryType.flags_to_types(required_delivery_types)

func get_normalized_required_weapon_capabilities() -> Array[StringName]:
	return WeaponCapability.flags_to_capabilities(required_weapon_capabilities)

func get_normalized_required_hooks() -> Array[StringName]:
	return ModuleHook.flags_to_hooks(required_hooks)

func get_hook_validation_error() -> String:
	for hook in get_normalized_required_hooks():
		var method_name: StringName = ModuleHook.METHOD_BY_HOOK.get(hook, StringName())
		if method_name == StringName() or not has_method(method_name):
			return "Declared hook '%s' requires method %s()." % [hook, method_name]
	return ""

func resolve_primary_damage_delivery(source_weapon: Weapon = weapon) -> StringName:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return StringName()
	var delivery_types := source_weapon.get_weapon_delivery_types()
	if delivery_types.is_empty():
		return StringName()
	return delivery_types[0]

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

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_drop_weight() -> float:
	return RARITY_UTIL.sanitize_weight(drop_weight, get_rarity())

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
	var level_effect := get_level_effect_description()
	if level_effect != "":
		descriptions.append(level_effect)
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

func get_level_effect_description(level: int = module_level) -> String:
	var index := clampi(level, 1, MAX_LEVEL) - 1
	if index >= level_effects.size():
		return ""
	return str(level_effects[index]).strip_edges()

func with_level_effect_descriptions(descriptions: PackedStringArray) -> PackedStringArray:
	var output := PackedStringArray()
	var level_effect := get_level_effect_description()
	if level_effect != "":
		output.append(level_effect)
	output.append_array(descriptions)
	return output

func _format_stat_label(stat_key: String) -> String:
	var pretty := stat_key.replace("_", " ")
	return pretty.capitalize()
