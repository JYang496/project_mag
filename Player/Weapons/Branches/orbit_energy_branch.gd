extends WeaponBranchBehavior
class_name OrbitEnergyBranch

const ENERGY_FIELD_INDICATOR_SCRIPT := preload("res://Player/Weapons/Branches/orbit_energy_field_indicator.gd")
const ENERGY_FIELD_INDICATOR_NODE_NAME := "EnergyFieldIndicator"

@export var field_radius: float = 84.0
@export var bonus_energy_ratio: float = 0.25
@export var min_bonus_energy_damage: int = 1
@export var per_target_trigger_icd_sec: float = 0.05
@export var show_field_indicator: bool = true
@export var indicator_fill_color: Color = Color(0.45, 0.8, 1.0, 0.10)
@export var indicator_outline_color: Color = Color(0.45, 0.9, 1.0, 0.75)
@export var indicator_outline_width: float = 1.5

var _target_next_trigger_msec: Dictionary = {}
var _indicator_sync_accum_sec: float = 0.0

func on_weapon_ready() -> void:
	set_process(true)
	_sync_satellite_indicators()

func on_level_applied(_level: int) -> void:
	_sync_satellite_indicators()

func on_removed() -> void:
	_target_next_trigger_msec.clear()
	_indicator_sync_accum_sec = 0.0
	_clear_satellite_indicators()
	set_process(false)

func _process(delta: float) -> void:
	_indicator_sync_accum_sec += maxf(delta, 0.0)
	if _indicator_sync_accum_sec < 0.2:
		return
	_indicator_sync_accum_sec = 0.0
	_sync_satellite_indicators()

func on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	if event_name != &"on_hit":
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	var target_value: Variant = detail.get("target", null)
	var target_node: Node2D = target_value as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return
	if not _is_inside_orbit_field(target_node):
		return
	if not _can_trigger_for_target(target_node):
		return
	_apply_bonus_energy_damage(target_node)

func _is_inside_orbit_field(target_node: Node2D) -> bool:
	if target_node == null or not is_instance_valid(target_node):
		return false
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.has_method("get_satellites"):
		return false
	var satellites_value: Variant = weapon.call("get_satellites")
	if not (satellites_value is Array):
		return false
	var satellites_array: Array = satellites_value
	var check_radius: float = maxf(field_radius, 1.0)
	for item in satellites_array:
		var satellite: Node2D = item as Node2D
		if satellite == null or not is_instance_valid(satellite):
			continue
		if satellite.global_position.distance_to(target_node.global_position) <= check_radius:
			return true
	return false

func _can_trigger_for_target(target_node: Node2D) -> bool:
	var target_id: int = target_node.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var next_msec: int = int(_target_next_trigger_msec.get(target_id, 0))
	if now_msec < next_msec:
		return false
	var icd_sec: float = maxf(per_target_trigger_icd_sec, 0.0)
	if icd_sec <= 0.0:
		return true
	_target_next_trigger_msec[target_id] = now_msec + int(icd_sec * 1000.0)
	return true

func _apply_bonus_energy_damage(target_node: Node2D) -> void:
	var runtime_damage: int = 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var bonus_damage: int = max(min_bonus_energy_damage, int(round(float(runtime_damage) * maxf(bonus_energy_ratio, 0.0))))
	var damage_data: DamageData = DamageManager.build_damage_data(
		weapon,
		bonus_damage,
		Attack.TYPE_ENERGY,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(target_node, damage_data)

func _sync_satellite_indicators() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("get_satellites"):
		return
	var satellites_value: Variant = weapon.call("get_satellites")
	if not (satellites_value is Array):
		return
	var satellites_array: Array = satellites_value
	for item in satellites_array:
		var satellite: Node2D = item as Node2D
		if satellite == null or not is_instance_valid(satellite):
			continue
		_sync_indicator_on_satellite(satellite)

func _sync_indicator_on_satellite(satellite: Node2D) -> void:
	var indicator: OrbitEnergyFieldIndicator = _find_indicator_on_satellite(satellite)
	if not show_field_indicator:
		if indicator != null and is_instance_valid(indicator):
			indicator.queue_free()
		return
	if indicator == null:
		indicator = ENERGY_FIELD_INDICATOR_SCRIPT.new() as OrbitEnergyFieldIndicator
		if indicator == null:
			return
		indicator.name = ENERGY_FIELD_INDICATOR_NODE_NAME
		satellite.call_deferred("add_child", indicator)
	indicator.radius = maxf(field_radius, 1.0)
	indicator.fill_color = indicator_fill_color
	indicator.outline_color = indicator_outline_color
	indicator.outline_width = maxf(indicator_outline_width, 0.5)

func _find_indicator_on_satellite(satellite: Node2D) -> OrbitEnergyFieldIndicator:
	var node: Node = satellite.get_node_or_null(ENERGY_FIELD_INDICATOR_NODE_NAME)
	if node == null or not is_instance_valid(node):
		return null
	return node as OrbitEnergyFieldIndicator

func _clear_satellite_indicators() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("get_satellites"):
		return
	var satellites_value: Variant = weapon.call("get_satellites")
	if not (satellites_value is Array):
		return
	var satellites_array: Array = satellites_value
	for item in satellites_array:
		var satellite: Node2D = item as Node2D
		if satellite == null or not is_instance_valid(satellite):
			continue
		var indicator: OrbitEnergyFieldIndicator = _find_indicator_on_satellite(satellite)
		if indicator != null and is_instance_valid(indicator):
			indicator.queue_free()
