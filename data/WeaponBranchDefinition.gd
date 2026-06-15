@tool
extends Resource
class_name WeaponBranchDefinition

@export var branch_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var unlock_fuse := 2
@export var sort_order := 0
@export_file("*.tscn") var weapon_scene_path := ""
@export_file("*.tscn") var behavior_scene_path := ""
@export var exclusive_groups: PackedStringArray = PackedStringArray()
@export var incompatible_branch_ids: PackedStringArray = PackedStringArray()

var _weapon_scene_cache: PackedScene
var _behavior_scene_cache: PackedScene
var weapon_scene: PackedScene:
	get:
		return get_weapon_scene()
var behavior_scene: PackedScene:
	get:
		return get_behavior_scene()

func get_weapon_scene() -> PackedScene:
	if _weapon_scene_cache == null and weapon_scene_path != "":
		_weapon_scene_cache = load(weapon_scene_path) as PackedScene
	return _weapon_scene_cache

func get_behavior_scene() -> PackedScene:
	if _behavior_scene_cache == null and behavior_scene_path != "":
		_behavior_scene_cache = load(behavior_scene_path) as PackedScene
	return _behavior_scene_cache
