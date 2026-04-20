extends Resource
class_name DpsBenchmarkConfig

@export var weapon_ids: PackedStringArray = PackedStringArray([
	"1", # machine gun
	"5", # pistol
	"4", # shotgun
	"8", # rocket launcher
	"9", # laser
	"17", # plasma lance
	"21", # glacier projector
	"25", # cannon
	"26", # sniper
])
@export var weapon_level: int = 1
@export var rounds_per_case: int = 1
@export var warmup_sec: float = 1.0
@export var test_duration_sec: float = 10.0
@export var auto_start_on_ready: bool = false
@export var force_mouse_to_target: bool = true
@export var quit_on_completion: bool = true
@export var script_hit_simulation: bool = true
@export var sim_target_hit_radius: float = 18.0
@export var sim_beam_tick_hz: float = 30.0
@export var accelerated_mode: bool = true
@export var simulation_time_scale: float = 4.0
@export var generate_summary_report: bool = true
@export var regression_check_enabled: bool = true
@export var min_fire_success_ratio: float = 0.03
@export var min_hit_count: int = 1
@export var expected_dps_ranges: Dictionary = {}
@export var auto_discover_standalone_weapons: bool = true
@export var auto_discover_all_weapon_ids: bool = false
@export var include_aoe_cases: bool = true

@export var player_position: Vector2 = Vector2(360, 360)
@export var single_group_position: Vector2 = Vector2(860, 360)
@export var aoe_group_center: Vector2 = Vector2(1160, 360)
@export var aoe_cluster_radius: float = 50.0

@export var single_target_hp: int = 3500
@export var aoe_target_hp: int = 1800
@export var aoe_target_count: int = 5

@export var report_dir: String = "res://docs/dps_reports"
@export var report_file_prefix: String = "dps_benchmark"

func build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var ids := _resolve_weapon_ids()
	for weapon_id in ids:
		for round_idx in range(maxi(rounds_per_case, 1)):
			queue.append({
				"weapon_id": str(weapon_id),
				"group_type": "single",
				"round": round_idx + 1,
			})
			if include_aoe_cases:
				queue.append({
					"weapon_id": str(weapon_id),
					"group_type": "aoe",
					"round": round_idx + 1,
				})
	return queue

func _resolve_weapon_ids() -> PackedStringArray:
	if auto_discover_all_weapon_ids:
		if GlobalVariables.weapon_list.is_empty():
			DataHandler.load_weapon_data()
		var all_ids: Array[String] = []
		for key_variant in GlobalVariables.weapon_list.keys():
			all_ids.append(str(key_variant))
		if not all_ids.is_empty():
			all_ids.sort_custom(func(a: String, b: String) -> bool:
				return int(a) < int(b)
			)
			return PackedStringArray(all_ids)
	if auto_discover_standalone_weapons:
		var ids: Array[String] = DataHandler.get_standalone_weapon_ids()
		if not ids.is_empty():
			ids.sort_custom(func(a: String, b: String) -> bool:
				return int(a) < int(b)
			)
			return PackedStringArray(ids)
	return weapon_ids
