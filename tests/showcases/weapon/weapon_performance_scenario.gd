extends RefCounted
class_name WeaponPerformanceScenario

var scenario_id := ""
var display_name := ""
var weapon_index := 0
var duration_sec := 6.0
var warmup_sec := 2.0
var cooldown_sec := 1.0
var repeat_count := 3
var random_seed := 20260919
var target_count := 12
var real_enemy_count := 0
var target_layout: StringName = &"ring"
var movement_pattern: StringName = &"stationary"
var aim_pattern: StringName = &"nearest"
var fire_pattern: StringName = &"continuous"
var skill_pattern: StringName = &"once"
var hud_enabled := false
var vfx_enabled := true
var cold_cache_mode := false
var tags: Array[StringName] = []


static func from_dictionary(data: Dictionary) -> WeaponPerformanceScenario:
	var scenario := WeaponPerformanceScenario.new()
	scenario.scenario_id = str(data.get("scenario_id", scenario.scenario_id))
	scenario.display_name = str(data.get("display_name", scenario.display_name))
	scenario.weapon_index = int(data.get("weapon_index", scenario.weapon_index))
	scenario.duration_sec = float(data.get("duration_sec", scenario.duration_sec))
	scenario.warmup_sec = float(data.get("warmup_sec", scenario.warmup_sec))
	scenario.cooldown_sec = float(data.get("cooldown_sec", scenario.cooldown_sec))
	scenario.repeat_count = int(data.get("repeat_count", scenario.repeat_count))
	scenario.random_seed = int(data.get("random_seed", scenario.random_seed))
	scenario.target_count = int(data.get("target_count", scenario.target_count))
	scenario.real_enemy_count = int(data.get("real_enemy_count", scenario.real_enemy_count))
	scenario.target_layout = StringName(data.get("target_layout", scenario.target_layout))
	scenario.movement_pattern = StringName(data.get("movement_pattern", scenario.movement_pattern))
	scenario.aim_pattern = StringName(data.get("aim_pattern", scenario.aim_pattern))
	scenario.fire_pattern = StringName(data.get("fire_pattern", scenario.fire_pattern))
	scenario.skill_pattern = StringName(data.get("skill_pattern", scenario.skill_pattern))
	scenario.hud_enabled = bool(data.get("hud_enabled", scenario.hud_enabled))
	scenario.vfx_enabled = bool(data.get("vfx_enabled", scenario.vfx_enabled))
	scenario.cold_cache_mode = bool(data.get("cold_cache_mode", scenario.cold_cache_mode))
	scenario.tags.clear()
	for tag in data.get("tags", []) as Array:
		scenario.tags.append(StringName(tag))
	return scenario


func to_dictionary() -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"display_name": display_name,
		"weapon_index": weapon_index,
		"duration_sec": duration_sec,
		"warmup_sec": warmup_sec,
		"cooldown_sec": cooldown_sec,
		"repeat_count": repeat_count,
		"random_seed": random_seed,
		"target_count": target_count,
		"real_enemy_count": real_enemy_count,
		"target_layout": str(target_layout),
		"movement_pattern": str(movement_pattern),
		"aim_pattern": str(aim_pattern),
		"fire_pattern": str(fire_pattern),
		"skill_pattern": str(skill_pattern),
		"hud_enabled": hud_enabled,
		"vfx_enabled": vfx_enabled,
		"cold_cache_mode": cold_cache_mode,
		"tags": Array(tags),
	}


static func quick_suite(current_weapon_index: int) -> Array[WeaponPerformanceScenario]:
	return [
		from_dictionary({
			"scenario_id": "empty_world_baseline",
			"display_name": "空场基线",
			"weapon_index": current_weapon_index,
			"duration_sec": 5.0,
			"warmup_sec": 2.0,
			"target_count": 0,
			"fire_pattern": &"none",
			"skill_pattern": &"none",
			"tags": [&"baseline"],
		}),
		from_dictionary({
			"scenario_id": "single_target_sustained_fire",
			"display_name": "单靶持续射击",
			"weapon_index": current_weapon_index,
			"duration_sec": 7.0,
			"target_count": 1,
			"fire_pattern": &"continuous",
			"skill_pattern": &"none",
			"tags": [&"weapon", &"sustained"],
		}),
		from_dictionary({
			"scenario_id": "skill_burst_twelve_targets",
			"display_name": "十二靶技能爆发",
			"weapon_index": current_weapon_index,
			"duration_sec": 7.0,
			"target_count": 12,
			"fire_pattern": &"continuous",
			"skill_pattern": &"once",
			"tags": [&"weapon", &"skill", &"burst"],
		}),
		from_dictionary({
			"scenario_id": "moving_combat_30",
			"display_name": "低密度移动战",
			"weapon_index": current_weapon_index,
			"duration_sec": 8.0,
			"target_count": 30,
			"real_enemy_count": 30,
			"movement_pattern": &"circle",
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"tags": [&"movement", &"combat"],
		}),
	]


static func stress_suite(current_weapon_index: int) -> Array[WeaponPerformanceScenario]:
	var scenarios := quick_suite(current_weapon_index)
	scenarios.append_array([
		from_dictionary({
			"scenario_id": "high_density_120",
			"display_name": "高密度持续战",
			"weapon_index": current_weapon_index,
			"duration_sec": 10.0,
			"warmup_sec": 3.0,
			"target_count": 120,
			"real_enemy_count": 120,
			"movement_pattern": &"figure_eight",
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"tags": [&"stress", &"enemy_density"],
		}),
		from_dictionary({
			"scenario_id": "projectile_pressure",
			"display_name": "投射物压力",
			"weapon_index": 0,
			"duration_sec": 10.0,
			"target_count": 60,
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"tags": [&"stress", &"projectile"],
		}),
		from_dictionary({
			"scenario_id": "area_effect_pressure",
			"display_name": "范围效果压力",
			"weapon_index": 10,
			"duration_sec": 10.0,
			"target_count": 60,
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"tags": [&"stress", &"area_effect"],
		}),
		from_dictionary({
			"scenario_id": "spawn_death_storm",
			"display_name": "生成与死亡风暴",
			"weapon_index": current_weapon_index,
			"duration_sec": 10.0,
			"target_count": 80,
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"tags": [&"stress", &"lifecycle"],
		}),
	])
	return scenarios


static func all_weapon_suite(weapon_count: int) -> Array[WeaponPerformanceScenario]:
	var scenarios: Array[WeaponPerformanceScenario] = []
	for weapon_index in weapon_count:
		scenarios.append(from_dictionary({
			"scenario_id": "weapon_%02d_standard" % (weapon_index + 1),
			"display_name": "武器 %02d 标准序列" % (weapon_index + 1),
			"weapon_index": weapon_index,
			"duration_sec": 14.0,
			"warmup_sec": 2.0,
			"cooldown_sec": 2.0,
			"target_count": 12,
			"fire_pattern": &"standard_sequence",
			"skill_pattern": &"once",
			"tags": [&"weapon_matrix"],
		}))
	return scenarios


static func extreme_performance_suite(weapon_count: int) -> Array[WeaponPerformanceScenario]:
	var scenarios: Array[WeaponPerformanceScenario] = []
	for weapon_index in weapon_count:
		scenarios.append(from_dictionary({
			"scenario_id": "extreme_weapon_%02d" % (weapon_index + 1),
			"display_name": "极限敌群 · 武器 %02d" % (weapon_index + 1),
			"weapon_index": weapon_index,
			"duration_sec": 10.0,
			"warmup_sec": 3.0,
			"cooldown_sec": 0.5,
			"repeat_count": 1,
			"random_seed": 20260919,
			"target_count": 120,
			"real_enemy_count": 120,
			"target_layout": &"ring",
			"movement_pattern": &"figure_eight",
			"fire_pattern": &"continuous",
			"skill_pattern": &"periodic",
			"hud_enabled": true,
			"tags": [&"extreme_performance", &"enemy_density", &"weapon_matrix"],
		}))
	return scenarios
