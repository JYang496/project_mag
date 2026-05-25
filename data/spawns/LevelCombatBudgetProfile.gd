extends Resource
class_name LevelCombatBudgetProfile

@export var level_target_total_hp: PackedInt32Array = []
@export_enum("level_share") var weight_mode: String = "level_share"

@export_group("HP Adjustment")
@export var min_hp: int = 1
@export var max_hp: int = 9999
@export_range(0.0, 1.0, 0.001) var tolerance_pct: float = 0.02
@export_enum("nearest", "floor", "ceil") var rounding_mode: String = "nearest"

@export_group("Validation")
@export var enable_hp_per_sec_report: bool = true
@export_range(0.0, 1.0, 0.001) var hp_per_sec_tolerance_pct: float = 0.08

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
	tolerance_pct = clampf(tolerance_pct, 0.0, 1.0)
	hp_per_sec_tolerance_pct = clampf(hp_per_sec_tolerance_pct, 0.0, 1.0)
	if weight_mode != "level_share":
		weight_mode = "level_share"
	if rounding_mode != "nearest" and rounding_mode != "floor" and rounding_mode != "ceil":
		rounding_mode = "nearest"
