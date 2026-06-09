extends RefCounted
class_name ProjectileEmitter

const LINEAR_MOVEMENT_SCENE_PATH := "res://Player/Weapons/Effects/linear_movement.tscn"
const POOLED_EFFECTS := {
	"linear_movement": true,
}

var weapon: Node
var _effect_scene_cache: Dictionary = {}
var _effect_schema_cache: Dictionary = {}

func setup(source_weapon: Node) -> void:
	weapon = source_weapon

func get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for config in _get_effect_configs():
		if config == null:
			warnings.append("Effect config list contains null entries.")
			continue
		if not EffectRegistry.has_effect(config.effect_id):
			warnings.append("Unknown effect id in effect_configs: %s" % str(config.effect_id))
	return warnings

func apply_effects_on_projectile(projectile: Node2D) -> void:
	if projectile == null:
		return
	var active_modifiers := _build_active_projectile_modifiers()
	bind_source_weapon(projectile)
	apply_base_movement(projectile)
	apply_modifiers(projectile, active_modifiers)
	if weapon.has_method("notify_projectile_spawned"):
		weapon.call("notify_projectile_spawned", projectile)
	_update_projectile_debug_snapshot(projectile, active_modifiers)

func bind_source_weapon(projectile: Node2D) -> void:
	if projectile is Projectile:
		(projectile as Projectile).source_weapon = weapon

func apply_base_movement(projectile: Node2D) -> void:
	var projectile_direction: Variant = weapon.get("projectile_direction")
	if projectile_direction == null:
		return
	if not (projectile_direction is Vector2):
		return
	var direction := projectile_direction as Vector2
	var speed_value := float(weapon.get("speed"))
	if is_zero_approx(speed_value):
		return
	projectile.rotation = direction.angle() + deg_to_rad(90.0)
	var movement_scene := get_effect_scene("linear_movement")
	var movement_node := spawn_effect_instance("linear_movement", movement_scene)
	if movement_node == null:
		return
	if movement_node.has_method("configure"):
		movement_node.call("configure", {"direction": direction, "speed": speed_value})
	else:
		movement_node.set("direction", direction)
		movement_node.set("speed", speed_value)
	projectile.call_deferred("add_child", movement_node)
	if projectile is Projectile:
		(projectile as Projectile).effect_list.append(movement_node)

func apply_modifiers(projectile: Node2D, active_modifiers: Dictionary) -> void:
	for effect_name in active_modifiers.keys():
		var effect_scene := get_effect_scene(str(effect_name))
		if effect_scene == null:
			_warn_projectile_modifier("effect '%s' scene not found." % str(effect_name))
			continue
		var raw_params: Variant = active_modifiers[effect_name]
		if not (raw_params is Dictionary):
			_warn_projectile_modifier("effect '%s' params must be Dictionary." % str(effect_name))
			continue
		var params := _validated_modifier_params(str(effect_name), effect_scene, raw_params)
		var effect_ins := spawn_effect_instance(str(effect_name), effect_scene)
		if effect_ins == null:
			continue
		if effect_ins.has_method("configure"):
			effect_ins.call("configure", params)
		else:
			for attribute in params.keys():
				effect_ins.set(str(attribute), params[attribute])
		projectile.call_deferred("add_child", effect_ins)
		if projectile is Projectile:
			(projectile as Projectile).effect_list.append(effect_ins)

func build_active_projectile_modifiers() -> Dictionary:
	return _build_modifiers_from_configs()

func _build_active_projectile_modifiers() -> Dictionary:
	return build_active_projectile_modifiers()

func _build_modifiers_from_configs() -> Dictionary:
	var output := {}
	var sorted_configs := _get_effect_configs().duplicate()
	sorted_configs.sort_custom(Callable(self, "_sort_effect_config_by_priority"))
	for raw_config in sorted_configs:
		var config := raw_config as EffectConfig
		if config == null:
			_warn_projectile_modifier("null effect config ignored.")
			continue
		if not config.enabled:
			continue
		if str(config.effect_id) == "linear_movement":
			_warn_projectile_modifier("effect config 'linear_movement' is managed by apply_base_movement() and will be ignored.")
			continue
		if not EffectRegistry.has_effect(config.effect_id):
			_warn_projectile_modifier("effect config id '%s' is not registered." % str(config.effect_id))
			continue
		var params: Dictionary = config.build_params()
		output[str(config.effect_id)] = params.duplicate(true)
	return output

func _sort_effect_config_by_priority(a: Variant, b: Variant) -> bool:
	var config_a := a as EffectConfig
	var config_b := b as EffectConfig
	if config_a == null:
		return false
	if config_b == null:
		return true
	return config_a.priority < config_b.priority

func get_effect_config(effect_id: StringName) -> EffectConfig:
	for config in _get_effect_configs():
		if config != null and config.effect_id == effect_id:
			return config
	return null

func ensure_effect_config(effect_id: StringName) -> EffectConfig:
	var existing := get_effect_config(effect_id)
	if existing != null:
		return existing
	var created := EffectRegistry.create_default_config(effect_id)
	if created == null:
		_warn_projectile_modifier("cannot create typed config for unregistered effect '%s'." % str(effect_id))
		return null
	var effect_configs := _get_effect_configs()
	effect_configs.append(created)
	weapon.set("effect_configs", effect_configs)
	if weapon.has_method("update_configuration_warnings"):
		weapon.call("update_configuration_warnings")
	return created

func get_effect_scene(effect_name: String) -> PackedScene:
	if _effect_scene_cache.has(effect_name):
		return _effect_scene_cache[effect_name]
	if effect_name == "linear_movement":
		var movement_scene := load(LINEAR_MOVEMENT_SCENE_PATH)
		if movement_scene is PackedScene:
			_effect_scene_cache[effect_name] = movement_scene
			return movement_scene
		return null
	var loaded_scene := EffectRegistry.get_scene(effect_name)
	if loaded_scene is PackedScene:
		_effect_scene_cache[effect_name] = loaded_scene
		return loaded_scene
	return null

func _validated_modifier_params(effect_name: String, effect_scene: PackedScene, params: Dictionary) -> Dictionary:
	var output := {}
	var schema := _get_or_build_effect_schema(effect_name, effect_scene)
	var expected_types: Dictionary = schema.get("types", {})
	for key in params.keys():
		var key_name := str(key)
		if not expected_types.has(key_name):
			_warn_projectile_modifier("effect '%s' unknown property '%s'." % [effect_name, key_name])
			continue
		var expected_type: int = int(expected_types[key_name])
		var value: Variant = params[key]
		if not _is_value_compatible(expected_type, value):
			_warn_projectile_modifier(
				"effect '%s' property '%s' expects %s, got %s." %
				[effect_name, key_name, type_string(expected_type), type_string(typeof(value))]
			)
			continue
		output[key_name] = value
	return output

func _get_or_build_effect_schema(effect_name: String, effect_scene: PackedScene) -> Dictionary:
	if _effect_schema_cache.has(effect_name):
		return _effect_schema_cache[effect_name]
	var instance: Node = effect_scene.instantiate()
	var type_map := {}
	for prop in instance.get_property_list():
		var usage: int = int(prop.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name == "":
			continue
		type_map[prop_name] = int(prop.get("type", TYPE_NIL))
	instance.queue_free()
	var schema := {"types": type_map}
	_effect_schema_cache[effect_name] = schema
	return schema

func _is_value_compatible(expected_type: int, value: Variant) -> bool:
	var actual_type := typeof(value)
	if expected_type == TYPE_NIL:
		return true
	if actual_type == expected_type:
		return true
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		return true
	return false

func spawn_effect_instance(effect_name: String, effect_scene: PackedScene) -> Node:
	if effect_scene == null:
		return null
	var object_pool := get_object_pool()
	if object_pool and _is_effect_poolable(effect_name):
		var pooled: Node = object_pool.acquire(effect_scene)
		if pooled != null:
			pooled.set_meta("_pool_enabled", true)
			return pooled
	var instantiated := effect_scene.instantiate()
	if instantiated:
		instantiated.set_meta("_pool_enabled", false)
	return instantiated

func spawn_projectile_from_scene(scene: PackedScene) -> Node2D:
	if scene == null:
		return null
	var object_pool := get_object_pool()
	if object_pool:
		var pooled: Node = object_pool.acquire(scene)
		if pooled is Node2D:
			return pooled as Node2D
	var inst := scene.instantiate()
	if inst is Node2D:
		return inst as Node2D
	return null

func get_projectile_spawn_parent() -> Node:
	var tree := weapon.get_tree()
	var current_scene := tree.current_scene
	if current_scene:
		return current_scene
	if PlayerData.player and PlayerData.player.get_parent():
		return PlayerData.player.get_parent()
	return tree.root

func get_object_pool() -> Node:
	var tree := weapon.get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null
	return root.get_node_or_null("ObjectPool")

func _update_projectile_debug_snapshot(projectile: Node2D, active_modifiers: Dictionary) -> void:
	if not (projectile is Projectile):
		return
	var proj := projectile as Projectile
	var effect_names: Array[String] = []
	for effect_name in active_modifiers.keys():
		effect_names.append(str(effect_name))
	var projectile_direction: Variant = weapon.get("projectile_direction")
	var speed_value := float(weapon.get("speed"))
	if projectile_direction != null and not is_zero_approx(speed_value):
		if not effect_names.has("linear_movement"):
			effect_names.append("linear_movement")
	proj.set_debug_snapshot(weapon.name, effect_names, active_modifiers, bool(weapon.get("debug_projectile_effects")))

func _get_effect_configs() -> Array:
	var value: Variant = weapon.get("effect_configs")
	if value is Array:
		return value
	return []

func _is_effect_poolable(effect_name: String) -> bool:
	return bool(POOLED_EFFECTS.get(effect_name, false))

func _warn_projectile_modifier(message: String) -> void:
	if OS.is_debug_build():
		push_warning("[ProjectileEmitter:%s] %s" % [weapon.name, message])
