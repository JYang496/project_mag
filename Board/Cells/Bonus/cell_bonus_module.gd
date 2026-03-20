extends Node
class_name CellBonusModule

var _cell: Cell

func setup(cell: Cell) -> void:
	_cell = cell

func apply_parameters(_params: Dictionary) -> void:
	# Override in subclasses to receive parameters from CellProfile
	pass

func grant_reward(_reward_type: int) -> void:
	pass

func get_reward_summary(_reward_type: int) -> String:
	return ""

func on_phase_changed(_new_phase: String) -> void:
	pass

func reset_runtime() -> void:
	pass
