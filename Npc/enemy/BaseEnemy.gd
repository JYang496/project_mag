extends BaseNPC
class_name BaseEnemy

@export var damage := 0
@export var coin_value := 1
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")


func death() -> void:
	queue_free()
