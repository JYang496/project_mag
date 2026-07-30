extends WeaponBranchBehavior
class_name OrbitEnergyBranch

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_added_delivery_types() -> Array[StringName]:
	return [DamageDeliveryType.AREA]

const ENERGY_FIELD_INDICATOR_SCRIPT := preload("res://Player/Weapons/Branches/orbit_energy_field_indicator.gd")
const ENERGY_FIELD_INDICATOR_NODE_NAME := "EnergyFieldIndicator"

@export var field_radius: float = 84.0
@export var bonus_energy_ratio: float = 0.25
@export var min_bonus_energy_damage: int = 1
@export var show_field_indicator: bool = true
@export var indicator_fill_color: Color = Color(PALETTE.ENERGY, 0.10)
@export var indicator_outline_color: Color = Color(PALETTE.PLAYER_PRIMARY, 0.52)
@export var indicator_outline_width: float = 1.5

var _indicator_sync_accum_sec: float = 0.0

func on_weapon_ready() -> void:
	set_process(true)
	_sync_satellite_indicators()

func on_level_applied(_level: int) -> void:
	_sync_satellite_indicators()

func on_removed() -> void:
	_indicator_sync_accum_sec = 0.0
	_clear_satellite_indicators()
	set_process(false)

func _process(delta: float) -> void:
	_indicator_sync_accum_sec += maxf(delta, 0.0)
	if _indicator_sync_accum_sec < 0.2:
		return
	_indicator_sync_accum_sec = 0.0
	_sync_satellite_indicators()

func get_energy_hit_passive_id() -> StringName:
	return &"orbit_energy_cycle"

func get_energy_hit_display_name() -> String:
	return "Orbital Pulse"

func on_energy_hit_cycle_triggered(target: Node, _data: DamageData, _result: DamageResult) -> Dictionary:
	if weapon == null or not is_instance_valid(weapon):
		return {}
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return {}
	var affected := 0
	for enemy in WeaponModuleRuntimeUtils.get_nearby_enemies(
		weapon.get_tree(),
		target_node.global_position,
		maxf(field_radius, 1.0)
	):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _apply_bonus_energy_damage(enemy):
			affected += 1
	return {
		"effect": "orbital_radial_pulse",
		"affected_targets": affected,
		"radius": maxf(field_radius, 1.0),
	}

func _apply_bonus_energy_damage(target_node: Node2D) -> bool:
	var runtime_damage: int = 1
	if weapon.has_method("get_runtime_shot_damage"):
		runtime_damage = max(1, int(weapon.call("get_runtime_shot_damage")))
	var bonus_damage: int = max(min_bonus_energy_damage, int(round(float(runtime_damage) * maxf(bonus_energy_ratio, 0.0))))
	var damage_data: DamageData = DamageManager.build_damage_data(
		weapon,
		bonus_damage,
		Attack.TYPE_ENERGY,
		{"amount": 0, "angle": Vector2.ZERO},
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	damage_data.suppress_reactive_effects = true
	return DamageManager.apply_to_target(target_node, damage_data)

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
