extends BaseNPC
class_name BaseEnemy

@export var damage := 0
@export var metal_value := 1
@onready var coin_preload = preload("res://Objects/loots/coin.tscn")

signal enemy_death()

func death() -> void:
	enemy_death.emit()
	var metal_ins = coin_preload.instantiate()
	metal_ins.global_position = self.global_position
	self.get_tree().root.call_deferred("add_child",metal_ins)
	queue_free()
