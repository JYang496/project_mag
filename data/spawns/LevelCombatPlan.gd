extends Resource
class_name LevelCombatPlan

@export var time_out_sec: int = 30
@export var target_total_hp: int = 1000
@export var spawns: Array[EnemySpawnEntry] = []

func sanitize() -> void:
	time_out_sec = maxi(time_out_sec, 1)
	target_total_hp = maxi(target_total_hp, 1)
	for entry in spawns:
		if entry != null:
			entry.sanitize()
