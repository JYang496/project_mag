extends BaseNPC
class_name BaseEnemy

@export var damage := 0
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")
@onready var drop_preload = preload("res://Objects/loots/drop.tscn")

signal enemy_death()

func death() -> void:
	var drop = drop_preload.instantiate()
	drop.drop = coin_preload
	drop.value = hp / 10 + 1
	drop.global_position = self.global_position
	self.call_deferred("add_sibling",drop)
	enemy_death.emit()
	queue_free()
