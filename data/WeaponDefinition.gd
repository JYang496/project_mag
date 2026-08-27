@tool
extends Resource
class_name WeaponDefinition

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const BUILD_TAG := preload("res://Player/Weapons/Core/build_tag.gd")

@export var weapon_id := ""
@export var display_name := ""
@export var icon: Texture2D
@export var price := 0
@export_multiline var description := ""
@export_file("*.tscn") var scene_path := ""
@export var core_tags: Array[StringName] = []
@export var is_hidden: bool = false
@export_enum("common", "rare", "epic") var rarity: String = "common"
@export_range(0.0, 1000000.0, 0.01) var drop_weight: float = 100.0

var _scene_cache: PackedScene
var _scene_request_started := false
var scene: PackedScene:
	get:
		return get_scene()

func get_scene() -> PackedScene:
	if _scene_cache != null or scene_path == "":
		return _scene_cache
	if _scene_request_started:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_scene_cache = ResourceLoader.load_threaded_get(scene_path) as PackedScene
			_scene_request_started = false
			return _scene_cache
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_scene_cache = ResourceLoader.load_threaded_get(scene_path) as PackedScene
			_scene_request_started = false
			return _scene_cache
		_scene_request_started = false
	_scene_cache = load(scene_path) as PackedScene
	return _scene_cache

func request_scene() -> Error:
	if _scene_cache != null or _scene_request_started or scene_path == "":
		return OK
	var error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if error == OK:
		_scene_request_started = true
	return error

func get_rarity() -> String:
	return RARITY_UTIL.normalize(rarity)

func get_drop_weight() -> float:
	return RARITY_UTIL.sanitize_weight(drop_weight, get_rarity())

func get_normalized_core_tags() -> Array[StringName]:
	var normalized := BUILD_TAG.normalize_array(core_tags)
	normalized.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return normalized

func get_unknown_core_tags() -> PackedStringArray:
	return BUILD_TAG.unknown_values(core_tags)
