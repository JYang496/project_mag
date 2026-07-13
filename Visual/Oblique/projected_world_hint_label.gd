class_name ProjectedWorldHintLabel
extends Label

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")

@export_range(1, 4, 1) var target_parent_levels: int = 1
@export var screen_offset: Vector2 = Vector2(0.0, -34.0)
var _target: Node2D

func _ready() -> void:
	var current: Node = get_parent()
	for _index in range(target_parent_levels - 1):
		if current != null:
			current = current.get_parent()
	_target = current as Node2D

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		visible = false
		return
	var anchor: Vector2 = ProjectedUi.project_to_canvas(self, _target.global_position)
	var canvas := get_viewport().get_canvas_transform()
	global_position = anchor + canvas.basis_xform_inv(screen_offset - size * Vector2(0.5, 0.5))
	rotation = 0.0
