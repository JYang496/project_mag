extends Resource
class_name ModuleProgressionProfile

@export var profile_id: StringName = &"default_weapon_module_progression"
@export var foundation_ids: PackedStringArray = []
@export var trigger_ids: PackedStringArray = []
@export var build_ids: PackedStringArray = []
@export var conversion_ids: PackedStringArray = []
@export_range(1.0, 10.0, 0.1) var newly_unlocked_weight_multiplier := 3.0
@export_range(1, 5, 1) var newly_unlocked_level_window := 2

const TRIGGER_UNLOCK_LEVEL := 3
const BUILD_UNLOCK_LEVEL := 6
const CONVERSION_UNLOCK_LEVEL := 9

func get_unlock_level(module_id: StringName) -> int:
	var normalized := str(module_id).strip_edges()
	if foundation_ids.has(normalized):
		return 0
	if trigger_ids.has(normalized):
		return TRIGGER_UNLOCK_LEVEL
	if build_ids.has(normalized):
		return BUILD_UNLOCK_LEVEL
	if conversion_ids.has(normalized):
		return CONVERSION_UNLOCK_LEVEL
	return -1

func is_unlocked(module_id: StringName, level_index: int, endless_mode: bool = false) -> bool:
	var unlock_level := get_unlock_level(module_id)
	return unlock_level >= 0 and (endless_mode or maxi(level_index, 0) >= unlock_level)

func is_newly_unlocked(module_id: StringName, level_index: int) -> bool:
	var unlock_level := get_unlock_level(module_id)
	if unlock_level <= 0:
		return false
	return level_index >= unlock_level and level_index < unlock_level + newly_unlocked_level_window

func get_all_ids() -> PackedStringArray:
	var result := PackedStringArray()
	result.append_array(foundation_ids)
	result.append_array(trigger_ids)
	result.append_array(build_ids)
	result.append_array(conversion_ids)
	return result

func get_tier_ids_for_level(level_index: int) -> PackedStringArray:
	match maxi(level_index, 0):
		TRIGGER_UNLOCK_LEVEL:
			return trigger_ids.duplicate()
		BUILD_UNLOCK_LEVEL:
			return build_ids.duplicate()
		CONVERSION_UNLOCK_LEVEL:
			return conversion_ids.duplicate()
		_:
			return PackedStringArray()
