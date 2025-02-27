extends Node2D
class_name Augment

@onready var player = get_tree().get_first_node_in_group("player")

var level := 1
var max_level := 5

signal update_aug_status()

func level_up(lvl = 1) -> void:
	level = clampi(level + lvl, 1, max_level)
	update_aug_status.emit()

func remove_augment_without_bonus() -> void:
	queue_free()
