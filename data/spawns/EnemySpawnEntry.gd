extends Resource
class_name EnemySpawnEntry

@export_file("*.tscn") var enemy_scene_path := ""
@export var start_sec: int = 1
@export var weight: int = 1

var _enemy_cache: PackedScene
var enemy: PackedScene:
	get:
		return get_enemy_scene()
	set(value):
		_enemy_cache = value
		enemy_scene_path = value.resource_path if value != null else ""

func get_enemy_scene() -> PackedScene:
	if _enemy_cache == null and enemy_scene_path != "":
		_enemy_cache = load(enemy_scene_path) as PackedScene
	return _enemy_cache

func sanitize() -> void:
	start_sec = maxi(start_sec, 0)
	weight = maxi(weight, 1)
