extends Weapon
class_name Ranger

const linear_movement = preload("res://Player/Weapons/Effects/linear_movement.tscn")

# Common variables for rangers
var base_damage : int
var damage : int
var base_speed : int
var speed : int
var base_projectile_hits : int
var projectile_hits : int
var dot_cd : float
var base_attack_cooldown : float
var attack_cooldown : float
var cooldown_timer : Timer
var size : float = 1.0
var projectile_direction
var is_on_cooldown = false
var _external_attack_speed_multiplier: float = 1.0

var module_list = []
var effect_sample = {"name":{"key1":123,"key2":234}}
@export var effect_configs: Array[EffectConfig] = []
var _effect_scene_cache: Dictionary = {
	"linear_movement": linear_movement,
}
var _effect_schema_cache: Dictionary = {}
@export var debug_projectile_effects: bool = false

var weapon_features = []
# Projectile scene that needs to be overwritten in child class.
var projectile_scene

const SPRITE_TARGET_HEIGHT := 30.0
const AIM_ROTATION_OFFSET := deg_to_rad(90)
const POOLED_EFFECTS := {
	"linear_movement": true,
}

signal shoot()
signal calculate_weapon_damage(damage)
signal calculate_weapon_projectile_hits(projectile_hits)
signal calculate_weapon_speed(speed)
signal calculate_attack_cooldown(attack_cooldown)
signal calculate_projectile_size(size)


func _ready():
	super._ready()
	setup_timer()
	_apply_fuse_sprite()
	_adjust_sprite_height()
	update_configuration_warnings()
	if level:
		set_level(level)
	else:
		# New weapon, create a weapon with level 1
		set_level(1)

# Surfaces editor warnings when effect config ids are invalid.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	for config in effect_configs:
		if config == null:
			warnings.append("Effect config list contains null entries.")
			continue
		if not EffectRegistry.has_effect(config.effect_id):
			warnings.append("Unknown effect id in effect_configs: %s" % str(config.effect_id))
	return warnings

func setup_timer() -> void:
	cooldown_timer = self.get_node("CooldownTimer")

func _physics_process(_delta):
	super._physics_process(_delta)
	_update_weapon_rotation()

func _on_cooldown_timer_timeout():
	is_on_cooldown = false

func _input(event: InputEvent) -> void:
	pass


func _on_shoot():
	is_on_cooldown = true
	var projectile := spawn_projectile_from_scene(projectile_scene)
	if projectile == null:
		return
	projectile.target = get_mouse_target()
	projectile.global_position = global_position
	get_projectile_spawn_parent().call_deferred("add_child", projectile)

func get_mouse_target():
	if has_meta("_benchmark_mouse_target"):
		var override_target: Variant = get_meta("_benchmark_mouse_target")
		if override_target is Vector2:
			return override_target
	if PlayerData.player and is_instance_valid(PlayerData.player):
		if PlayerData.player.has_meta("_benchmark_mouse_target"):
			var player_override: Variant = PlayerData.player.get_meta("_benchmark_mouse_target")
			if player_override is Vector2:
				return player_override
	return get_global_mouse_position()

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func uses_ammo_system() -> bool:
	return true

func request_primary_fire() -> bool:
	if not is_attack_phase_allowed():
		return false
	if is_on_cooldown:
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		# Auto-reload when trying to fire with an empty magazine.
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if not consume_ammo(1):
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if cooldown_timer:
		cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.01)
	emit_signal("shoot")
	register_shot_heat()
	if uses_ammo_system() and current_ammo <= 0:
		request_reload()
	return true

func set_external_attack_speed_multiplier(multiplier: float) -> void:
	_external_attack_speed_multiplier = clampf(multiplier, 0.1, 10.0)

func get_external_attack_speed_multiplier() -> float:
	return _external_attack_speed_multiplier

func get_effective_cooldown(base_cooldown: float) -> float:
	var speed_mul := maxf(_external_attack_speed_multiplier, 0.1)
	return maxf(base_cooldown / speed_mul, 0.01)

func start_weapon_cooldown(base_cooldown: float, min_cooldown: float = 0.01) -> void:
	if cooldown_timer == null:
		setup_timer()
	if cooldown_timer == null:
		return
	cooldown_timer.wait_time = maxf(get_effective_cooldown(base_cooldown), min_cooldown)
	cooldown_timer.start()

func _execute_weapon_active(_damage_multiplier: float) -> bool:
	# Keep ranger weapon active empty by design.
	return false

func _apply_weapon_active_multiplier_buff(damage_multiplier: float) -> void:
	if damage_multiplier <= 1.0:
		return
	var source_id := StringName("weapon_active_%s" % str(get_instance_id()))
	if PlayerData.player and is_instance_valid(PlayerData.player):
		PlayerData.player.apply_damage_mul(source_id, damage_multiplier)
		var clear_timer := get_tree().create_timer(0.15)
		clear_timer.timeout.connect(func() -> void:
			if PlayerData.player and is_instance_valid(PlayerData.player):
				PlayerData.player.remove_damage_mul(source_id)
		)

# This function calls before a projectile is added.
func apply_effects_on_projectile(projectile : Node2D) -> void:
	if projectile == null:
		return
	# Build a runtime snapshot so applying effects never mutates source config/state.
	var active_modifiers := _build_active_projectile_modifiers()
	bind_source_weapon(projectile)
	apply_base_movement(projectile)
	apply_modifiers(projectile, active_modifiers)
	notify_projectile_spawned(projectile)
	_update_projectile_debug_snapshot(projectile, active_modifiers)

# Binds the weapon for hit attribution and on-hit module callbacks.
func bind_source_weapon(projectile: Node2D) -> void:
	if projectile is Projectile:
		(projectile as Projectile).source_weapon = self

# Injects mandatory linear movement as a base effect stage.
func apply_base_movement(projectile: Node2D) -> void:
	if projectile_direction == null:
		return
	if speed == null or speed == 0:
		return
	# Set first-frame facing immediately to avoid one-frame rotation lag.
	projectile.rotation = projectile_direction.angle() + deg_to_rad(90.0)
	var movement_node := _spawn_effect_instance("linear_movement", linear_movement)
	if movement_node == null:
		return
	if movement_node.has_method("configure"):
		movement_node.call("configure", {"direction": projectile_direction, "speed": speed})
	else:
		movement_node.set("direction", projectile_direction)
		movement_node.set("speed", speed)
	projectile.call_deferred("add_child", movement_node)
	if projectile is Projectile:
		(projectile as Projectile).effect_list.append(movement_node)

# Applies validated effect modifiers built from typed configs.
func apply_modifiers(projectile: Node2D, active_modifiers: Dictionary) -> void:
	for effect_name in active_modifiers.keys():
		var effect_scene := _get_effect_scene(str(effect_name))
		if effect_scene == null:
			_warn_projectile_modifier("effect '%s' scene not found." % str(effect_name))
			continue
		var raw_params: Variant = active_modifiers[effect_name]
		if not (raw_params is Dictionary):
			_warn_projectile_modifier("effect '%s' params must be Dictionary." % str(effect_name))
			continue
		var params: Dictionary = _validated_modifier_params(str(effect_name), effect_scene, raw_params)
		var effect_ins := _spawn_effect_instance(str(effect_name), effect_scene)
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

# Builds active modifiers from typed EffectConfig resources.
func _build_active_projectile_modifiers() -> Dictionary:
	return _build_modifiers_from_configs()

# Converts exported EffectConfig resources to a runtime dictionary.
func _build_modifiers_from_configs() -> Dictionary:
	var output := {}
	var sorted_configs := effect_configs.duplicate()
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

# Sort callback used to make config application order deterministic.
func _sort_effect_config_by_priority(a: Variant, b: Variant) -> bool:
	var config_a := a as EffectConfig
	var config_b := b as EffectConfig
	if config_a == null:
		return false
	if config_b == null:
		return true
	return config_a.priority < config_b.priority

# Returns the first EffectConfig with the requested id.
func get_effect_config(effect_id: StringName) -> EffectConfig:
	for config in effect_configs:
		if config != null and config.effect_id == effect_id:
			return config
	return null

# Ensures a typed config exists; creates a default one through the registry when missing.
func ensure_effect_config(effect_id: StringName) -> EffectConfig:
	var existing := get_effect_config(effect_id)
	if existing != null:
		return existing
	var created := EffectRegistry.create_default_config(effect_id)
	if created == null:
		_warn_projectile_modifier("cannot create typed config for unregistered effect '%s'." % str(effect_id))
		return null
	effect_configs.append(created)
	update_configuration_warnings()
	return created

func _get_effect_scene(effect_name: String) -> PackedScene:
	if _effect_scene_cache.has(effect_name):
		return _effect_scene_cache[effect_name]
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
			_warn_projectile_modifier(
				"effect '%s' unknown property '%s'." % [effect_name, key_name]
			)
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

func _warn_projectile_modifier(message: String) -> void:
	if OS.is_debug_build():
		push_warning("[Ranger:%s] %s" % [name, message])

func _spawn_effect_instance(effect_name: String, effect_scene: PackedScene) -> Node:
	if effect_scene == null:
		return null
	var object_pool := _get_object_pool()
	if object_pool and _is_effect_poolable(effect_name):
		var pooled: Node = object_pool.acquire(effect_scene)
		if pooled != null:
			pooled.set_meta("_pool_enabled", true)
			return pooled
	var instantiated := effect_scene.instantiate()
	if instantiated:
		instantiated.set_meta("_pool_enabled", false)
	return instantiated

func _is_effect_poolable(effect_name: String) -> bool:
	return bool(POOLED_EFFECTS.get(effect_name, false))

func spawn_projectile_from_scene(scene: PackedScene) -> Node2D:
	if scene == null:
		return null
	var object_pool := _get_object_pool()
	if object_pool:
		var pooled: Node = object_pool.acquire(scene)
		if pooled is Node2D:
			return pooled as Node2D
	var inst := scene.instantiate()
	if inst is Node2D:
		return inst as Node2D
	return null

func _get_object_pool() -> Node:
	var tree := get_tree()
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
	if projectile_direction != null and speed:
		if not effect_names.has("linear_movement"):
			effect_names.append("linear_movement")
	proj.set_debug_snapshot(name, effect_names, active_modifiers, debug_projectile_effects)

func get_projectile_spawn_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene
	if PlayerData.player and PlayerData.player.get_parent():
		return PlayerData.player.get_parent()
	return get_tree().root

func apply_effects(projectile) -> void:
	pass

func sync_stats() -> void:
	damage = base_damage
	projectile_hits = base_projectile_hits
	attack_cooldown = base_attack_cooldown
	speed = base_speed
	apply_module_stat_pipeline()
	if cooldown_timer == null:
		setup_timer()
	set_cd_timer(cooldown_timer)
	set_projectile_size(size)
	calculate_damage(damage)
	calculate_projectile_hits(projectile_hits)

func calculate_damage(pre_damage : int) -> void:
	calculate_weapon_damage.emit(pre_damage)

func calculate_projectile_hits(pre_projectile_hits : int) -> void:
	calculate_weapon_projectile_hits.emit(pre_projectile_hits)

func calculate_speed(pre_speed) -> void:
	calculate_weapon_speed.emit(pre_speed)

func set_cd_timer(timer : Timer) -> void:
	calculate_attack_cooldown.emit(attack_cooldown)
	if timer != null and attack_cooldown > 0:
		timer.wait_time = attack_cooldown

func set_projectile_size(projectile_size : float) -> void:
	calculate_projectile_size.emit(projectile_size)

# Computes per-shot damage from base damage and current modules without mutating runtime stats.
func get_runtime_shot_damage() -> int:
	return get_runtime_damage_value(float(base_damage))

func remove_weapon() -> void:
	var idx := PlayerData.player_weapon_list.find(self)
	if idx >= 0:
		PlayerData.player_weapon_list.remove_at(idx)
	PlayerData.sanitize_main_weapon_index()
	PlayerData.on_select_weapon = PlayerData.main_weapon_index
	queue_free()

func _adjust_sprite_height() -> void:
	if not sprite or not sprite.texture:
		return
	var tex_height := float(sprite.texture.get_height())
	if tex_height <= 0.0:
		return
	var scale_factor := SPRITE_TARGET_HEIGHT / tex_height
	sprite.scale = Vector2(scale_factor, scale_factor)

func _update_weapon_rotation() -> void:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction == Vector2.ZERO:
		return
	rotation = mouse_direction.angle() + AIM_ROTATION_OFFSET

func supports_projectiles() -> bool:
	return true
