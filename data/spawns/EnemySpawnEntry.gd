extends Resource
class_name EnemySpawnEntry

@export var enemy: PackedScene
@export var start_sec: int = 1
@export var weight: int = 1

func sanitize() -> void:
	start_sec = maxi(start_sec, 0)
	weight = maxi(weight, 1)
