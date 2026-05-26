extends RefCounted
class_name SpawnCombatProfileValidator

var errors: Array[String] = []
var warnings: Array[String] = []

func validate(profile: SpawnCombatProfile) -> bool:
	errors.clear()
	warnings.clear()
	if profile == null:
		errors.append("SpawnCombatProfile is null.")
		return false
	profile.sanitize()
	if profile.levels.is_empty():
		errors.append("SpawnCombatProfile has no levels.")
	for level_index in range(profile.levels.size()):
		_validate_level(profile, level_index, profile.levels[level_index])
	return errors.is_empty()

func _validate_level(profile: SpawnCombatProfile, level_index: int, level: LevelCombatPlan) -> void:
	if level == null:
		errors.append("Level %d is null." % level_index)
		return
	if level.time_out_sec <= 0:
		errors.append("Level %d time_out_sec must be > 0." % level_index)
	if level.target_total_hp <= 0:
		errors.append("Level %d target_total_hp must be > 0." % level_index)
	if level.spawns.is_empty():
		errors.append("Level %d has no spawns." % level_index)
	var estimated_capacity_hp := 0
	for entry_index in range(level.spawns.size()):
		var entry := level.spawns[entry_index]
		if entry == null:
			errors.append("Level %d entry %d is null." % [level_index, entry_index])
			continue
		if entry.enemy == null:
			errors.append("Level %d entry %d has no enemy." % [level_index, entry_index])
			continue
		if entry.weight <= 0:
			errors.append("Level %d entry %d weight must be > 0." % [level_index, entry_index])
		if entry.start_sec >= level.time_out_sec:
			errors.append("Level %d entry %d start_sec must be < time_out_sec." % [level_index, entry_index])
		var metadata := _read_enemy_metadata(profile, entry)
		if int(metadata.get("spawn_cost", 0)) <= 0:
			errors.append("Level %d entry %d enemy has invalid spawn_cost." % [level_index, entry_index])
		var active_seconds := maxi(level.time_out_sec - entry.start_sec, 0)
		var batch_cap := _safe_int(metadata.get("spawn_batch_cap", 0), 0)
		if batch_cap <= 0:
			batch_cap = profile.max_same_type_per_batch
		estimated_capacity_hp += active_seconds * maxi(batch_cap, 1) * profile.max_hp
	if estimated_capacity_hp <= 0:
		return
	var min_allowed := int(round(float(level.target_total_hp) * (1.0 - profile.hp_per_sec_tolerance_pct)))
	if estimated_capacity_hp < min_allowed:
		warnings.append(
			"Level %d estimated spawn capacity HP %d is below target %d."
			% [level_index, estimated_capacity_hp, level.target_total_hp]
		)

func _read_enemy_metadata(profile: SpawnCombatProfile, entry: EnemySpawnEntry) -> Dictionary:
	var metadata := {
		"spawn_cost": profile.default_enemy_cost,
		"spawn_tags": [],
		"spawn_batch_cap": 0,
		"base_hp": 1,
	}
	var scene_path := entry.enemy.resource_path
	if scene_path == "":
		return metadata
	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return metadata
	var text := file.get_as_text()
	var cost_match := RegEx.create_from_string("(?m)^spawn_cost = (\\d+)").search(text)
	if cost_match != null:
		metadata["spawn_cost"] = maxi(int(cost_match.get_string(1)), 1)
	var hp_match := RegEx.create_from_string("(?m)^hp = (\\d+)").search(text)
	if hp_match != null:
		metadata["base_hp"] = maxi(int(hp_match.get_string(1)), 1)
	var batch_cap_match := RegEx.create_from_string("(?m)^spawn_batch_cap = (\\d+)").search(text)
	if batch_cap_match != null:
		metadata["spawn_batch_cap"] = maxi(int(batch_cap_match.get_string(1)), 0)
	var tags: Array[StringName] = []
	if text.find('&"ranged"') != -1:
		tags.append(&"ranged")
	if text.find('&"elite"') != -1:
		tags.append(&"elite")
	metadata["spawn_tags"] = tags
	return metadata

func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	return int(value)
