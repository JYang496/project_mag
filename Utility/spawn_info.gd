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
var alive_enemy_number = 0
var interval_counter = 0
var wave = 0

func add_enemy_with_signal (i) -> void:
	if not i.is_connected("enemy_death",Callable(self,"remove_enemy_from_list")):
		alive_enemy_number += 1
		i.connect("enemy_death",Callable(self,"remove_enemy_from_list"))

func remove_enemy_from_list() -> void:
	alive_enemy_number -= 1
