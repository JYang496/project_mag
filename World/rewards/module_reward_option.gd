extends Resource
class_name ModuleRewardOption

@export var module_scene: PackedScene
@export_range(0.0, 1000000.0, 0.01) var weight: float = 1.0
@export_range(1, 3, 1) var min_level: int = 1
@export_range(1, 3, 1) var max_level: int = 1

func get_clamped_min_level() -> int:
	return clampi(min_level, 1, 3)

func get_clamped_max_level() -> int:
	return clampi(max_level, get_clamped_min_level(), 3)
