extends Module
# Projectiles leave short-lived freeze damage zones along their path.

const AREA_EFFECT_SCENE: PackedScene = preload("res://Utility/area_effect/area_effect.tscn")
const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Frost Trail"

@export var trail_radius: float = 34.0
@export var trail_tick_interval: float = 0.35
@export var trail_sample_interval: float = 0.08
@export var trail_min_spacing: float = 24.0
@export var duration_lv1: float = 1.6
@export var duration_lv2: float = 2.0
@export var duration_lv3: float = 2.4
@export var damage_ratio_lv1: float = 0.18
@export var damage_ratio_lv2: float = 0.24
@export var damage_ratio_lv3: float = 0.30
@export var max_active_fields: int = 18

var _tracked_projectiles: Dictionary = {}
var _field_refs: Array[WeakRef] = []
var _plugin_registered: bool = false

func _enter_tree() -> void:
	super._enter_tree()
	_register_plugin()

func _ready() -> void:
	_register_plugin()

func _exit_tree() -> void:
	_unregister_plugin()

func _physics_process(delta: float) -> void:
	_process_projectiles(delta)

func on_projectile_spawned(source_weapon: Weapon, projectile: Node2D) -> void:
	if source_weapon == null or source_weapon != weapon:
		return
	if projectile == null or not is_instance_valid(projectile):
		return
	_tracked_projectiles[projectile.get_instance_id()] = {
		"projectile_ref": weakref(projectile),
		"last_position": projectile.global_position,
		"sample_accum": 0.0,
	}

func get_effect_descriptions() -> PackedStringArray:
	return PackedStringArray([
		"Projectiles leave freeze AoE trails",
		"Trail duration %.1fs" % _get_duration(),
	])

func _register_plugin() -> void:
	if _plugin_registered:
		return
	if weapon == null:
		weapon = _resolve_weapon()
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("register_projectile_spawn_plugin"):
		return
	weapon.call("register_projectile_spawn_plugin", self)
	_plugin_registered = true

func _unregister_plugin() -> void:
	if not _plugin_registered:
		return
	if weapon != null and is_instance_valid(weapon) and weapon.has_method("unregister_projectile_spawn_plugin"):
		weapon.call("unregister_projectile_spawn_plugin", self)
	_plugin_registered = false

func _process_projectiles(delta: float) -> void:
	if _tracked_projectiles.is_empty():
		return
	var sample_step := maxf(trail_sample_interval, 0.02)
	for projectile_id in _tracked_projectiles.keys():
		var payload_variant: Variant = _tracked_projectiles.get(projectile_id, {})
		if not (payload_variant is Dictionary):
			_tracked_projectiles.erase(projectile_id)
			continue
		var payload: Dictionary = payload_variant
		var projectile_ref: WeakRef = payload.get("projectile_ref", null)
		var projectile: Node2D = null
		if projectile_ref != null:
			projectile = projectile_ref.get_ref() as Node2D
		if projectile == null or not is_instance_valid(projectile):
			_tracked_projectiles.erase(projectile_id)
			continue
		var sample_accum := float(payload.get("sample_accum", 0.0)) + maxf(delta, 0.0)
		if sample_accum < sample_step:
			payload["sample_accum"] = sample_accum
			_tracked_projectiles[projectile_id] = payload
			continue
		sample_accum = 0.0
		var previous_position: Variant = payload.get("last_position", projectile.global_position)
		if previous_position is Vector2 and (previous_position as Vector2).distance_to(projectile.global_position) >= maxf(trail_min_spacing, 4.0):
			_spawn_trail_field(projectile.global_position)
			payload["last_position"] = projectile.global_position
		payload["sample_accum"] = sample_accum
		_tracked_projectiles[projectile_id] = payload

func _spawn_trail_field(spawn_position: Vector2) -> void:
	var area_effect := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if area_effect == null:
		return
	area_effect.radius = maxf(trail_radius, 8.0)
	area_effect.duration = _get_duration()
	area_effect.target_group = AreaEffect.TargetGroup.ENEMIES
	area_effect.apply_once_per_target = false
	area_effect.damage_type = Attack.TYPE_FREEZE
	area_effect.tick_interval = maxf(trail_tick_interval, 0.05)
	area_effect.tick_damage = _get_tick_damage()
	area_effect.source_node = weapon
	area_effect.global_position = spawn_position
	var tree := get_tree()
	if tree == null:
		area_effect.queue_free()
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	if parent == null:
		area_effect.queue_free()
		return
	parent.call_deferred("add_child", area_effect)
	_track_field(area_effect)

func _track_field(area_effect: AreaEffect) -> void:
	if area_effect == null:
		return
	_cleanup_fields()
	_field_refs.append(weakref(area_effect))
	while _field_refs.size() > max(1, max_active_fields):
		var oldest_ref: WeakRef = _field_refs[0]
		_field_refs.remove_at(0)
		if oldest_ref == null:
			continue
		var oldest: Object = oldest_ref.get_ref()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

func _cleanup_fields() -> void:
	for i in range(_field_refs.size() - 1, -1, -1):
		var field: Object = _field_refs[i].get_ref()
		if field == null or not is_instance_valid(field):
			_field_refs.remove_at(i)

func _get_duration() -> float:
	return UTILS.get_value_by_level(module_level, duration_lv1, duration_lv2, duration_lv3)

func _get_damage_ratio() -> float:
	return UTILS.get_value_by_level(module_level, damage_ratio_lv1, damage_ratio_lv2, damage_ratio_lv3)

func _get_tick_damage() -> int:
	return max(1, int(round(float(UTILS.get_runtime_weapon_damage(weapon)) * _get_damage_ratio())))
