extends Resource
class_name SpawnBalanceProfile

@export_group("Levels")
@export var level_configs: Array[LevelSpawnConfig] = []

@export_group("Batch Budget")
@export var base_budget_by_level: PackedInt32Array = [6, 8, 10, 12, 14, 16, 18, 20, 22, 24]
@export_range(0.0, 1.0, 0.01) var early_phase_ratio: float = 0.30
@export_range(0.0, 1.0, 0.01) var late_phase_ratio: float = 0.70
@export_range(0.1, 5.0, 0.01) var early_phase_multiplier: float = 0.85
@export_range(0.1, 5.0, 0.01) var mid_phase_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.01) var late_phase_multiplier: float = 1.2
@export var surge_interval_sec: int = 15
@export var surge_bonus_budget: int = 2

@export_group("Batch Limits")
@export var max_same_type_per_batch: int = 4
@export var max_ranged_per_batch: int = 3
@export var max_selection_attempts: int = 96

@export_group("Enemy Cost")
@export var default_enemy_cost: int = 3
@export var enemy_cost_by_scene_path: Dictionary = {
	"res://Npc/enemy/scenes/enemy_rolling_ball.tscn": 1,
	"res://Npc/enemy/scenes/enemy_wheel_cart.tscn": 2,
	"res://Npc/enemy/scenes/enemy_mine_crawler.tscn": 2,
	"res://Npc/enemy/scenes/enemy_tar_mine_crawler.tscn": 3,
	"res://Npc/enemy/scenes/enemy_bomber.tscn": 3,
	"res://Npc/enemy/scenes/enemy_spike_turret.tscn": 3,
	"res://Npc/enemy/scenes/enemy_orbit_support.tscn": 4,
	"res://Npc/enemy/scenes/enemy_mortar_turret.tscn": 5,
	"res://Npc/enemy/scenes/enemy_mirror_caster.tscn": 5,
	"res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn": 6,
}

@export_group("Infinite Mode")
@export var infinite_mode_start_level_index: int = 10
@export_range(0.0, 2.0, 0.01) var infinite_hp_growth_per_level: float = 0.18
@export_range(0.0, 2.0, 0.01) var infinite_damage_growth_per_level: float = 0.08
@export_range(0.0, 2.0, 0.01) var infinite_budget_growth_per_level: float = 0.05

func sanitize() -> void:
	if base_budget_by_level.is_empty():
		base_budget_by_level = [1]
	early_phase_ratio = clampf(early_phase_ratio, 0.0, 1.0)
	late_phase_ratio = clampf(late_phase_ratio, early_phase_ratio, 1.0)
	early_phase_multiplier = maxf(early_phase_multiplier, 0.1)
	mid_phase_multiplier = maxf(mid_phase_multiplier, 0.1)
	late_phase_multiplier = maxf(late_phase_multiplier, 0.1)
	surge_interval_sec = maxi(surge_interval_sec, 0)
	surge_bonus_budget = maxi(surge_bonus_budget, 0)
	max_same_type_per_batch = maxi(max_same_type_per_batch, 1)
	max_ranged_per_batch = maxi(max_ranged_per_batch, 0)
	max_selection_attempts = maxi(max_selection_attempts, 1)
	default_enemy_cost = maxi(default_enemy_cost, 1)
	infinite_mode_start_level_index = maxi(infinite_mode_start_level_index, 1)
	infinite_hp_growth_per_level = maxf(infinite_hp_growth_per_level, 0.0)
	infinite_damage_growth_per_level = maxf(infinite_damage_growth_per_level, 0.0)
	infinite_budget_growth_per_level = maxf(infinite_budget_growth_per_level, 0.0)

func get_base_budget_for_level(level_index: int) -> int:
	if base_budget_by_level.is_empty():
		return 1
	var clamped_level := clampi(level_index, 0, base_budget_by_level.size() - 1)
	return maxi(int(base_budget_by_level[clamped_level]), 1)

func get_enemy_cost(scene_path: String) -> int:
	if scene_path == "":
		return default_enemy_cost
	return maxi(int(enemy_cost_by_scene_path.get(scene_path, default_enemy_cost)), 1)

func get_infinite_overflow_level(level_index: int) -> int:
	return maxi(level_index - (infinite_mode_start_level_index - 1), 0)
