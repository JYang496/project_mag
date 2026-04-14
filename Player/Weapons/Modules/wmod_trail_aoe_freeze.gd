extends Module

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")
const TRAIL_AREA_EFFECT_SCRIPT := preload("res://Utility/area_effect/trail_area_effect.gd")

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
@export var show_trail_range: bool = true
@export var trail_fill_color: Color = Color(0.35, 0.85, 1.0, 0.18)
@export var trail_line_color: Color = Color(0.45, 0.95, 1.0, 0.75)
@export var trail_line_width: float = 1.5

var _plugin_registered: bool = false
var _trail_effect: Node

func _enter_tree() -> void:
	super._enter_tree()
	_ensure_trail_effect()
	_register_plugin()

func _ready() -> void:
	_ensure_trail_effect()
	_register_plugin()

func _exit_tree() -> void:
	_unregister_plugin()
	if _trail_effect != null and is_instance_valid(_trail_effect):
		_trail_effect.queue_free()
	_trail_effect = null

func _physics_process(delta: float) -> void:
	_ensure_trail_effect()
	_sync_trail_effect_config()
	if _trail_effect != null and is_instance_valid(_trail_effect):
		_trail_effect.step(delta)

func on_projectile_spawned(source_weapon: Weapon, projectile: Node2D) -> void:
	if source_weapon == null or source_weapon != weapon:
		return
	if projectile == null or not is_instance_valid(projectile):
		return
	_ensure_trail_effect()
	_sync_trail_effect_config()
	if _trail_effect == null or not is_instance_valid(_trail_effect):
		return
	_trail_effect.attach_emitter(
		projectile,
		_resolve_trail_radius(projectile),
		trail_min_spacing,
		_should_prime_on_first_step(source_weapon)
	)

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

func _ensure_trail_effect() -> void:
	if _trail_effect != null and is_instance_valid(_trail_effect):
		return
	var effect_node := TRAIL_AREA_EFFECT_SCRIPT.new()
	if effect_node == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	if parent == null:
		return
	effect_node.name = "TrailAreaEffect_%s" % str(get_instance_id())
	effect_node.auto_process = false
	parent.add_child(effect_node)
	_trail_effect = effect_node

func _sync_trail_effect_config() -> void:
	if _trail_effect == null or not is_instance_valid(_trail_effect):
		return
	_trail_effect.source_node = weapon
	_trail_effect.duration = _get_duration()
	_trail_effect.tick_interval = maxf(trail_tick_interval, 0.05)
	_trail_effect.sample_interval = maxf(trail_sample_interval, 0.02)
	_trail_effect.max_segments = max(1, max_active_fields)
	_trail_effect.target_group = 0
	_trail_effect.tick_damage = _get_tick_damage()
	_trail_effect.damage_type = Attack.TYPE_FREEZE
	_trail_effect.stack_damage_per_segment = false
	_trail_effect.draw_enabled = show_trail_range
	_trail_effect.fill_color = trail_fill_color
	_trail_effect.line_color = trail_line_color
	_trail_effect.line_width = maxf(trail_line_width, 0.5)

func _resolve_trail_radius(projectile: Node2D) -> float:
	if projectile != null and is_instance_valid(projectile):
		var projectile_size: Variant = projectile.get("size")
		if projectile_size != null:
			return maxf(float(projectile_size), 0.1)
	return maxf(trail_radius, 0.1)

func _get_duration() -> float:
	return UTILS.get_value_by_level(module_level, duration_lv1, duration_lv2, duration_lv3)

func _get_damage_ratio() -> float:
	return UTILS.get_value_by_level(module_level, damage_ratio_lv1, damage_ratio_lv2, damage_ratio_lv3)

func _get_tick_damage() -> int:
	return max(1, int(round(float(UTILS.get_runtime_weapon_damage(weapon)) * _get_damage_ratio())))

func _should_prime_on_first_step(source_weapon: Weapon) -> bool:
	if source_weapon == null or not is_instance_valid(source_weapon):
		return false
	var item_name: Variant = source_weapon.get("ITEM_NAME")
	if item_name != null and str(item_name) == "Orbit":
		return true
	var script_ref: Script = source_weapon.get_script()
	if script_ref != null and String(script_ref.resource_path).ends_with("/orbit.gd"):
		return true
	return false
