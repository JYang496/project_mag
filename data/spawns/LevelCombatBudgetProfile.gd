extends Resource
class_name LevelCombatBudgetProfile

@export var level_target_total_hp: PackedInt32Array = PackedInt32Array([
	1800,
	3200,
	5200,
	7600,
	9800,
	12200,
	15000,
	18200,
	21800,
	25800,
])
@export_enum("level_share") var weight_mode: String = "level_share"

@export_group("HP Adjustment")
@export var min_hp: int = 1
@export var max_hp: int = 9999
@export_range(0.0, 1.0, 0.001) var tolerance_pct: float = 0.02
@export_enum("nearest", "floor", "ceil") var rounding_mode: String = "nearest"

@export_group("Validation")
@export var enable_hp_per_sec_report: bool = true
@export_range(0.0, 1.0, 0.001) var hp_per_sec_tolerance_pct: float = 0.08

@export_group("Wave Limit Adjustment")
@export var adjust_batch_limits_from_hp_budget: bool = true
@export var max_same_type_per_batch_from_budget: int = 64
@export var max_total_batch_cost_from_hp_budget: int = 256

func get_target_total_hp(level_index: int) -> int:
	if level_target_total_hp.is_empty():
		return 0
	var safe_level := maxi(level_index, 0)
	if safe_level < level_target_total_hp.size():
		return maxi(int(level_target_total_hp[safe_level]), 0)
	return maxi(int(level_target_total_hp[level_target_total_hp.size() - 1]), 0)

func sanitize() -> void:
	min_hp = maxi(min_hp, 1)
	max_hp = maxi(max_hp, min_hp)
	max_same_type_per_batch_from_budget = maxi(max_same_type_per_batch_from_budget, 1)
	max_total_batch_cost_from_hp_budget = maxi(max_total_batch_cost_from_hp_budget, 1)
	tolerance_pct = clampf(tolerance_pct, 0.0, 1.0)
	hp_per_sec_tolerance_pct = clampf(hp_per_sec_tolerance_pct, 0.0, 1.0)
	if weight_mode != "level_share":
		weight_mode = "level_share"
	if rounding_mode != "nearest" and rounding_mode != "floor" and rounding_mode != "ceil":
		rounding_mode = "nearest"
