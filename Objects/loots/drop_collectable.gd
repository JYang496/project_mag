extends Node2D

@export var item_id: String = "1"
@export var level: int = 3
@export var module_scene: PackedScene
@export var module_level: int = 1
@export var value: int = 0
@export var spawn_ready: bool = false
@export var auto_collect_on_landing: bool = false
@export var trajectory_animation_managed: bool = false
@export var settle_unclaimed_on_battle_start: bool = false


func start_drop_flip() -> void:
	pass


func uses_screen_height_trajectory() -> bool:
	return false


func set_trajectory_screen_height(_height: float) -> void:
	pass


func sync_trajectory_visual() -> void:
	pass


func activate_pickup_detection() -> void:
	spawn_ready = true


func collect_automatically() -> void:
	pass
