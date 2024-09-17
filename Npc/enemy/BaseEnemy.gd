extends BaseNPC
class_name BaseEnemy

@export var damage := 0
@export var coin_value := 1
@onready var coin_preload = preload("res://Objects/coin.tscn")

func death() -> void:
	var coin = coin_preload.instantiate()
	coin.value = coin_value
	coin.global_position = self.global_position
	self.add_sibling(coin)
	queue_free()
