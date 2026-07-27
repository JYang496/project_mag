extends Resource
class_name DamageLabelStyleProfile

const TIER_MINOR := 0
const TIER_NORMAL := 1
const TIER_HEAVY := 2
const TIER_BURST := 3

@export_range(0.0, 1.0, 0.001) var normal_ratio_threshold: float = 0.02
@export_range(0.0, 1.0, 0.001) var heavy_ratio_threshold: float = 0.08
@export_range(0.0, 1.0, 0.001) var burst_ratio_threshold: float = 0.20
@export var fallback_normal_damage: int = 8
@export var fallback_heavy_damage: int = 24
@export var fallback_burst_damage: int = 60

@export var tier_pixel_scales := PackedInt32Array([1, 1, 2, 3])
@export var tier_pop_distances := PackedFloat32Array([28.0, 40.0, 56.0, 72.0])
@export var tier_lifetimes := PackedFloat32Array([0.26, 0.32, 0.40, 0.48])
@export var tier_outline_pixels := PackedInt32Array([1, 1, 1, 2])
@export var physical_horizontal_ratio: float = 0.18
@export var energy_horizontal_ratio: float = 0.46
@export var fire_horizontal_ratio: float = 0.12
@export var freeze_horizontal_ratio: float = 0.05
@export var mixed_horizontal_ratio: float = 0.26
@export var fire_distance_multiplier: float = 1.15
@export var freeze_distance_multiplier: float = 0.82
@export var periodic_distance_multiplier: float = 0.75
@export var fire_lifetime_bonus: float = 0.06
@export var freeze_lifetime_bonus: float = 0.04
@export var critical_lifetime_bonus: float = 0.08

@export var physical_color := Color(1.0, 0.96, 0.82, 1.0)
@export var energy_color := Color(0.76, 0.48, 1.0, 1.0)
@export var fire_color := Color(1.0, 0.34, 0.20, 1.0)
@export var freeze_color := Color(0.36, 0.94, 1.0, 1.0)
@export var mixed_color := Color(0.82, 0.86, 0.88, 1.0)
@export var critical_color := Color(1.0, 0.82, 0.22, 1.0)
@export var outline_color := Color(0.035, 0.045, 0.06, 0.96)
@export var periodic_outline_color := Color(0.12, 0.15, 0.18, 0.92)

func resolve_tier(damage: int, target_max_hp: int) -> int:
	if target_max_hp > 0:
		var ratio := float(max(0, damage)) / float(target_max_hp)
		if ratio >= burst_ratio_threshold:
			return TIER_BURST
		if ratio >= heavy_ratio_threshold:
			return TIER_HEAVY
		if ratio >= normal_ratio_threshold:
			return TIER_NORMAL
		return TIER_MINOR
	if damage >= fallback_burst_damage:
		return TIER_BURST
	if damage >= fallback_heavy_damage:
		return TIER_HEAVY
	if damage >= fallback_normal_damage:
		return TIER_NORMAL
	return TIER_MINOR

func get_pixel_scale(tier: int, is_critical: bool) -> int:
	var value := _read_int(tier_pixel_scales, tier, 1)
	if is_critical:
		value += 1
	return clampi(value, 1, 3)

func get_pop_distance(tier: int, damage_type: StringName) -> float:
	var value := _read_float(tier_pop_distances, tier, 40.0)
	match damage_type:
		Attack.TYPE_FIRE:
			return value * fire_distance_multiplier
		Attack.TYPE_FREEZE:
			return value * freeze_distance_multiplier
		_:
			return value

func get_lifetime(tier: int, damage_type: StringName, is_critical: bool) -> float:
	var value := _read_float(tier_lifetimes, tier, 0.32)
	if damage_type == Attack.TYPE_FIRE:
		value += fire_lifetime_bonus
	elif damage_type == Attack.TYPE_FREEZE:
		value += freeze_lifetime_bonus
	if is_critical:
		value += critical_lifetime_bonus
	return value

func get_horizontal_ratio(damage_type: StringName) -> float:
	match damage_type:
		Attack.TYPE_ENERGY:
			return energy_horizontal_ratio
		Attack.TYPE_FIRE:
			return fire_horizontal_ratio
		Attack.TYPE_FREEZE:
			return freeze_horizontal_ratio
		&"mixed":
			return mixed_horizontal_ratio
		_:
			return physical_horizontal_ratio

func get_outline_pixels(tier: int, is_critical: bool) -> int:
	var value := _read_int(tier_outline_pixels, tier, 1)
	return clampi(value + (1 if is_critical else 0), 1, 2)

func get_color(damage_type: StringName, _is_critical: bool) -> Color:
	match damage_type:
		Attack.TYPE_ENERGY:
			return energy_color
		Attack.TYPE_FIRE:
			return fire_color
		Attack.TYPE_FREEZE:
			return freeze_color
		&"mixed":
			return mixed_color
		_:
			return physical_color

func _read_int(values: PackedInt32Array, index: int, fallback: int) -> int:
	if values.is_empty():
		return fallback
	return int(values[clampi(index, 0, values.size() - 1)])

func _read_float(values: PackedFloat32Array, index: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	return float(values[clampi(index, 0, values.size() - 1)])
