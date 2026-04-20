extends Resource
class_name WeaponFormulaBenchmarkConfig

@export var weapon_ids: PackedStringArray = PackedStringArray([])
@export var weapon_level: int = 7
@export var rounds_per_case: int = 1
@export var warmup_sec: float = 0.6
@export var test_duration_sec: float = 20.0
@export var auto_start_on_ready: bool = false
@export var quit_on_completion: bool = true
@export var force_mouse_to_target: bool = true
@export var accelerated_mode: bool = true
@export var simulation_time_scale: float = 4.0
@export var auto_discover_standalone_weapons: bool = true
@export var branch_by_weapon_id: Dictionary = {}

@export var player_position: Vector2 = Vector2(360, 360)
@export var target_position: Vector2 = Vector2(540, 360)
@export var target_hp: int = 500000

@export var report_dir: String = "res://docs"
@export var report_file_prefix: String = "weapon_dps_formula"

# Formula tuning knobs
@export var formula_target_count: float = 1.0
@export var laser_beam_duration_sec: float = 0.2
@export var laser_beam_tick_hz: float = 60.0
@export var orbit_satellite_lifetime_sec: float = 5.0
@export var orbit_hits_per_second_per_satellite: float = 1.2
@export var chainsaw_contact_duration_sec: float = 1.2
@export var rocket_single_target_multiplier: float = 1.5
@export var sniper_distance_multiplier: float = 1.45
@export var sniper_expected_pierce_hits: int = 0
@export var plasma_expected_pierce_hits: int = 1

func build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var ids: PackedStringArray = _resolve_weapon_ids()
	for weapon_id in ids:
		for round_idx in range(maxi(rounds_per_case, 1)):
			queue.append({
				"weapon_id": str(weapon_id),
				"round": round_idx + 1,
			})
	return queue

func _resolve_weapon_ids() -> PackedStringArray:
	if auto_discover_standalone_weapons:
		if GlobalVariables.weapon_list.is_empty():
			DataHandler.load_weapon_data()
		var ids: Array[String] = DataHandler.get_standalone_weapon_ids()
		if not ids.is_empty():
			ids.sort_custom(func(a: String, b: String) -> bool:
				return int(a) < int(b)
			)
			return PackedStringArray(ids)
	return weapon_ids

func get_branch_for_weapon(weapon_id: String) -> String:
	if not branch_by_weapon_id.has(weapon_id):
		return ""
	return str(branch_by_weapon_id.get(weapon_id, "")).strip_edges()
