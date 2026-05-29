extends Resource
class_name SpawnCombatProfile

@export_group("Levels")
@export var levels: Array[LevelCombatPlan] = []

@export_group("Pressure")
@export var pressure_points: Array[PressurePoint] = []
@export var max_hp_budget_carryover_seconds: int = 3

@export_group("Batch Limits")
@export var max_same_type_per_batch: int = 4
@export var max_ranged_per_batch: int = 3
@export var max_selection_attempts: int = 96

@export_group("Alive Limits")
@export var default_alive_cap_per_type: int = 80
@export var default_total_alive_cap: int = 240

@export_group("Validation")
@export var enable_hp_per_sec_report: bool = true
@export_range(0.0, 1.0, 0.001) var hp_per_sec_tolerance_pct: float = 0.08

@export_group("Infinite Mode")
@export var infinite_mode_start_level_index: int = 10
@export_range(0.0, 2.0, 0.01) var infinite_hp_growth_per_level: float = 0.18
@export_range(0.0, 2.0, 0.01) var infinite_damage_growth_per_level: float = 0.08

func sanitize() -> void:
	for level in levels:
		if level != null:
			level.sanitize()
	if pressure_points.is_empty():
		pressure_points.append(_make_pressure_point(0.0, 0.85))
		pressure_points.append(_make_pressure_point(0.7, 1.0))
		pressure_points.append(_make_pressure_point(1.0, 1.2))
	for point in pressure_points:
		if point != null:
			point.sanitize()
	pressure_points.sort_custom(func(a: PressurePoint, b: PressurePoint) -> bool:
		return float(a.t if a != null else 0.0) < float(b.t if b != null else 0.0)
	)
	max_hp_budget_carryover_seconds = maxi(max_hp_budget_carryover_seconds, 1)
	max_same_type_per_batch = maxi(max_same_type_per_batch, 1)
	max_ranged_per_batch = maxi(max_ranged_per_batch, 0)
	max_selection_attempts = maxi(max_selection_attempts, 1)
	default_alive_cap_per_type = maxi(default_alive_cap_per_type, 1)
	default_total_alive_cap = maxi(default_total_alive_cap, default_alive_cap_per_type)
	hp_per_sec_tolerance_pct = clampf(hp_per_sec_tolerance_pct, 0.0, 1.0)
	infinite_mode_start_level_index = maxi(infinite_mode_start_level_index, 1)
	infinite_hp_growth_per_level = maxf(infinite_hp_growth_per_level, 0.0)
	infinite_damage_growth_per_level = maxf(infinite_damage_growth_per_level, 0.0)

func get_level_plan(level_index: int) -> LevelCombatPlan:
	if levels.is_empty():
		return null
	var safe_level := clampi(level_index, 0, levels.size() - 1)
	return levels[safe_level]

func get_level_spawns(level_index: int) -> Array[EnemySpawnEntry]:
	var plan := get_level_plan(level_index)
	if plan == null:
		return []
	return plan.spawns.duplicate()

func get_level_time_out(level_index: int, fallback_value: int = 30) -> int:
	var plan := get_level_plan(level_index)
	if plan == null:
		return maxi(fallback_value, 1)
	return maxi(plan.time_out_sec, 1)

func get_target_total_hp(level_index: int) -> int:
	var plan := get_level_plan(level_index)
	if plan == null:
		return 0
	var target := maxi(plan.target_total_hp, 0)
	var overflow_level := get_infinite_overflow_level(level_index)
	if overflow_level > 0:
		target = max(1, int(round(float(target) * pow(1.0 + infinite_hp_growth_per_level, float(overflow_level)))))
	return target

func get_pressure_multiplier(progress: float) -> float:
	var safe_progress := clampf(progress, 0.0, 1.0)
	if pressure_points.is_empty():
		return 1.0
	var previous: PressurePoint = null
	for point in pressure_points:
		if point == null:
			continue
		if safe_progress <= point.t:
			if previous == null:
				return point.multiplier
			var span := maxf(point.t - previous.t, 0.001)
			var alpha := clampf((safe_progress - previous.t) / span, 0.0, 1.0)
			return lerpf(previous.multiplier, point.multiplier, alpha)
		previous = point
	return pressure_points.back().multiplier

func get_infinite_overflow_level(level_index: int) -> int:
	return maxi(level_index - (infinite_mode_start_level_index - 1), 0)

func _make_pressure_point(point_t: float, point_multiplier: float) -> PressurePoint:
	var point := PressurePoint.new()
	point.t = point_t
	point.multiplier = point_multiplier
	return point
