extends Node2D
class_name Effect

@onready var projectile: Projectile = self.find_parent("*") as Projectile
@onready var melee: Melee = self.find_parent("*") as Melee
@export var supports_ranged: bool = true
@export var supports_melee: bool = false

func _ready() -> void:
	if projectile:
		if not supports_ranged:
			queue_free()
			return
		projectile_effect_ready()
	elif melee:
		if not supports_melee:
			queue_free()
			return
		melee_effect_ready()

func configure(params: Dictionary) -> void:
	var type_map := _get_effect_property_type_map()
	for key in params.keys():
		var key_name := str(key)
		if not type_map.has(key_name):
			_warn_invalid_config("unknown property '%s'" % key_name)
			continue
		var expected_type: int = int(type_map[key_name])
		var value: Variant = params[key]
		if not _is_type_compatible(expected_type, value):
			_warn_invalid_config(
				"type mismatch on '%s': expected %s, got %s" %
				[key_name, type_string(expected_type), type_string(typeof(value))]
			)
			continue
		set(key_name, value)

func projectile_effect_ready() -> void:
	pass

func melee_effect_ready() -> void:
	pass

func claim_projectile_movement_control() -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if projectile.has_method("claim_movement_control"):
		projectile.call("claim_movement_control", self)

func has_projectile_movement_control() -> bool:
	if projectile == null or not is_instance_valid(projectile):
		return false
	if projectile.has_method("has_movement_control"):
		return bool(projectile.call("has_movement_control", self))
	return true

func _get_effect_property_type_map() -> Dictionary:
	var output := {}
	for prop in get_property_list():
		var usage: int = int(prop.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name == "":
			continue
		output[prop_name] = int(prop.get("type", TYPE_NIL))
	return output

func _is_type_compatible(expected_type: int, value: Variant) -> bool:
	var actual_type := typeof(value)
	if expected_type == TYPE_NIL:
		return true
	if actual_type == expected_type:
		return true
	# Allow int -> float assignment for convenient numeric configuration.
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		return true
	return false

func _warn_invalid_config(reason: String) -> void:
	if OS.is_debug_build():
		push_warning("[Effect:%s] Invalid configure params: %s" % [name, reason])
