extends Resource

class_name SpawnInfo

@export var time_start:int

@export var enemy:Resource
@export var number:int
@export var max_enemy_number:int
@export var hp:int
@export var damage:int
@export var max_wave:int
@export var interval:int
@export var hp_growth_per_level:float = 0.1
@export var damage_growth_per_level:float = 0.05
var alive_enemy_number = 0
var interval_counter = 0
var wave = 0

func add_enemy_with_signal (i) -> void:
	if not i.is_connected("enemy_death",Callable(self,"remove_enemy_from_list")):
		alive_enemy_number += 1
		i.connect("enemy_death",Callable(self,"remove_enemy_from_list"))

func remove_enemy_from_list() -> void:
	alive_enemy_number -= 1

func get_scaled_hp(level: int, fallback_value: int) -> int:
	return _scale_stat(hp, fallback_value, hp_growth_per_level, level, 1)

func get_scaled_damage(level: int, fallback_value: int) -> int:
	return _scale_stat(damage, fallback_value, damage_growth_per_level, level, 0)

func _scale_stat(override_value: int, fallback_value: int, growth_per_level: float, level: int, minimum: int) -> int:
	var base_value = override_value if override_value > 0 else fallback_value
	base_value = max(base_value, 0)
	var safe_level = max(level, 0)
	var multiplier = 1.0 + growth_per_level * safe_level
	multiplier = max(multiplier, 0.0)
	var scaled_value = int(round(base_value * multiplier))
	return max(minimum, scaled_value)
