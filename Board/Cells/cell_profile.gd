extends Resource
class_name CellProfile

@export_enum("NONE:0", "OFFENSE:1", "DEFENSE:2")
var task_type: int = Cell.TaskType.NONE
@export_enum("NONE:0", "COMBAT:1", "ECONOMY:2")
var reward_type: int = Cell.RewardType.NONE
@export_enum("NONE:0", "CORROSION:1", "JUNGLE:2")
var terrain_type: int = Cell.TerrainType.NONE
@export var objective_enabled := false
@export var aura_enabled := false

@export_group("Auto Mapping")
@export var use_auto_module_mapping := true
@export var use_manual_module_scenes := false

@export_group("Manual Modules")
@export var module_scenes: Array[PackedScene] = []

const TASK_OBJECTIVE_REGISTRY := {
	Cell.TaskType.OFFENSE: "res://Board/Cells/Modules/offense_kill_objective_module.tscn",
	Cell.TaskType.DEFENSE: "res://Board/Cells/Modules/defense_hold_objective_module.tscn"
}
const TERRAIN_AURA_REGISTRY := {
	Cell.TerrainType.CORROSION: "res://Board/Cells/Modules/corrosion_aura_module.tscn",
	Cell.TerrainType.JUNGLE: "res://Board/Cells/Modules/jungle_aura_module.tscn"
}
static var _SCENE_CACHE: Dictionary = {}

func resolve_module_scenes() -> Array[PackedScene]:
	var resolved: Array[PackedScene] = []
	if use_auto_module_mapping:
		if objective_enabled:
			_append_from_registry(resolved, TASK_OBJECTIVE_REGISTRY, task_type)
		if aura_enabled:
			_append_from_registry(resolved, TERRAIN_AURA_REGISTRY, terrain_type)
	if use_manual_module_scenes:
		for scene in module_scenes:
			if scene:
				resolved.append(scene)
	return _dedupe_module_scenes(resolved)

func _append_from_registry(output: Array[PackedScene], registry: Dictionary, enum_value: int) -> void:
	if not registry.has(enum_value):
		return
	var scene_path := str(registry[enum_value])
	var scene := _load_scene_cached(scene_path)
	if scene:
		output.append(scene)

func _load_scene_cached(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _SCENE_CACHE.has(scene_path):
		return _SCENE_CACHE[scene_path] as PackedScene
	var loaded = load(scene_path)
	if loaded is PackedScene:
		_SCENE_CACHE[scene_path] = loaded
		return loaded as PackedScene
	return null

func _dedupe_module_scenes(scenes: Array[PackedScene]) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var seen: Dictionary = {}
	for scene in scenes:
		if scene == null:
			continue
		var key := scene.resource_path
		if key == "":
			key = str(scene.get_instance_id())
		if seen.has(key):
			continue
		seen[key] = true
		result.append(scene)
	return result
