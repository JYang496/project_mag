extends Weapon
class_name Ranger

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
@export var spread_enabled: bool = false
@export var spread_full_distance: float = 900.0
@export var spread_no_falloff_distance: float = 0.0
@export var spread_close_range_miss_chance: float = 0.05
@export var spread_long_range_miss_chance: float = 0.85
@export var spread_min_radius: float = 6.0
@export var spread_max_radius: float = 140.0

@export var effect_configs: Array[EffectConfig] = []
@export var debug_projectile_effects: bool = false

# Projectile scene that needs to be overwritten in child class.
var projectile_scene

const SPRITE_TARGET_HEIGHT := 40.0
const AIM_ROTATION_OFFSET := deg_to_rad(90)

signal shoot()

var projectile_emitter: ProjectileEmitter = ProjectileEmitter.new()
var spread_model: WeaponSpreadModel = WeaponSpreadModel.new()
var fire_controller: WeaponFireController = WeaponFireController.new()
var _components_bound := false

func _ready():
	super._ready()
	_setup_components()
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
	_setup_components()
	return projectile_emitter.get_configuration_warnings()

func _setup_components() -> void:
	if _components_bound:
		return
	if projectile_emitter == null:
		projectile_emitter = ProjectileEmitter.new()
	projectile_emitter.setup(self)
	if spread_model == null:
		spread_model = WeaponSpreadModel.new()
	spread_model.setup(self)
	if fire_controller == null:
		fire_controller = WeaponFireController.new()
	fire_controller.setup(self)
	_components_bound = true

func setup_timer() -> void:
	_setup_components()
	fire_controller.setup_timer()

func _physics_process(_delta):
	super._physics_process(_delta)
	_update_weapon_rotation()

func _on_cooldown_timer_timeout():
	_setup_components()
	fire_controller.on_cooldown_timer_timeout()

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
	return fire_controller.request_primary_fire()

func set_external_attack_speed_multiplier(multiplier: float) -> void:
	fire_controller.set_external_attack_speed_multiplier(multiplier)

func apply_external_attack_speed_mul(source_id: StringName, multiplier: float) -> void:
	fire_controller.apply_external_attack_speed_mul(source_id, multiplier)

func remove_external_attack_speed_mul(source_id: StringName) -> void:
	fire_controller.remove_external_attack_speed_mul(source_id)

func get_external_attack_speed_multiplier() -> float:
	return fire_controller.get_external_attack_speed_multiplier()

func get_effective_cooldown(base_cooldown: float) -> float:
	return fire_controller.get_effective_cooldown(base_cooldown)

func set_external_spread_multiplier(multiplier: float) -> void:
	spread_model.set_external_spread_multiplier(multiplier)

func apply_external_spread_mul(source_id: StringName, multiplier: float) -> void:
	spread_model.apply_external_spread_mul(source_id, multiplier)

func remove_external_spread_mul(source_id: StringName) -> void:
	spread_model.remove_external_spread_mul(source_id)

func get_external_spread_multiplier() -> float:
	return spread_model.get_external_spread_multiplier()

func apply_distance_based_spread(direction: Vector2, shot_distance: float) -> Vector2:
	return spread_model.apply_distance_based_spread(direction, shot_distance)

func apply_distance_spread_to_target(direction: Vector2, target_position: Vector2) -> Vector2:
	return spread_model.apply_distance_spread_to_target(direction, target_position)

func _build_spread_runtime(shot_distance: float) -> Dictionary:
	return spread_model.build_spread_runtime(shot_distance)

func _sample_spread_target(base_target: Vector2, radius: float) -> Vector2:
	return spread_model.sample_spread_target(base_target, radius)

func get_spread_preview_radius_for_target(target_position: Vector2) -> float:
	return spread_model.get_spread_preview_radius_for_target(target_position)

func get_spread_preview_info_for_target(target_position: Vector2) -> Dictionary:
	return spread_model.get_spread_preview_info_for_target(target_position)

func _get_spread_distance_ratio(shot_distance: float) -> float:
	return spread_model.get_spread_distance_ratio(shot_distance)

func start_weapon_cooldown(base_cooldown: float, min_cooldown: float = 0.01) -> void:
	fire_controller.start_weapon_cooldown(base_cooldown, min_cooldown)

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
	projectile_emitter.apply_effects_on_projectile(projectile)

# Binds the weapon for hit attribution and on-hit module callbacks.
func bind_source_weapon(projectile: Node2D) -> void:
	projectile_emitter.bind_source_weapon(projectile)

# Injects mandatory linear movement as a base effect stage.
func apply_base_movement(projectile: Node2D) -> void:
	projectile_emitter.apply_base_movement(projectile)

# Applies validated effect modifiers built from typed configs.
func apply_modifiers(projectile: Node2D, active_modifiers: Dictionary) -> void:
	projectile_emitter.apply_modifiers(projectile, active_modifiers)

# Returns the first EffectConfig with the requested id.
func get_effect_config(effect_id: StringName) -> EffectConfig:
	return projectile_emitter.get_effect_config(effect_id)

# Ensures a typed config exists; creates a default one through the registry when missing.
func ensure_effect_config(effect_id: StringName) -> EffectConfig:
	return projectile_emitter.ensure_effect_config(effect_id)

func spawn_projectile_from_scene(scene: PackedScene) -> Node2D:
	return projectile_emitter.spawn_projectile_from_scene(scene)

func get_projectile_spawn_parent() -> Node:
	return projectile_emitter.get_projectile_spawn_parent()

func sync_stats() -> void:
	damage = base_damage
	projectile_hits = base_projectile_hits
	attack_cooldown = base_attack_cooldown
	speed = base_speed
	apply_module_stat_pipeline()
	_setup_components()
	fire_controller.sync_cooldown_timer()

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
