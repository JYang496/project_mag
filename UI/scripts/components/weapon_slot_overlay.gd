extends Control
class_name WeaponSlotOverlay

@onready var _surface: ColorRect = $Surface
var _state: Dictionary = {}

func _ready() -> void:
	_surface.material = _surface.material.duplicate()
	_apply_state({})

func set_state(next_state: Dictionary) -> void:
	if _state == next_state:
		return
	_state = next_state.duplicate(true)
	if is_node_ready():
		_apply_state(_state)

func set_reload_state(visible_value: bool, progress_value: float, color_value: Color, overheated_value: bool = false) -> void:
	var next := _state.duplicate(true)
	next["show_reload"] = visible_value
	next["reload_progress"] = clampf(progress_value, 0.0, 1.0)
	next["reload_color"] = color_value
	next["overheated"] = overheated_value
	set_state(next)

func set_passive_state(visible_value: bool, progress_value: float) -> void:
	var next := _state.duplicate(true)
	next["show_passive"] = visible_value
	next["passive_progress"] = clampf(progress_value, 0.0, 1.0)
	set_state(next)

func _apply_state(value: Dictionary) -> void:
	var material := _surface.material as ShaderMaterial
	for key in [
		"reload_progress", "skill_progress", "hold_progress", "passive_progress", "heat_progress",
		"show_reload", "show_skill", "show_hold", "show_passive", "overheated", "reload_color",
	]:
		if value.has(key):
			material.set_shader_parameter(key, value[key])
		elif key in ["show_reload", "show_skill", "show_hold", "show_passive", "overheated"]:
			material.set_shader_parameter(key, false)
