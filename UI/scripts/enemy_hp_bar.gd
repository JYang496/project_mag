extends Node2D
class_name EnemyHpBar

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")

@export var offset_y: float = -30.0

@onready var bar: ProgressBar = $Bar
@onready var hide_timer: Timer = $HideTimer

func _ready() -> void:
	visible = false
	hide_timer.one_shot = true
	_sync_position()

func _process(_delta: float) -> void:
	_sync_position()

func set_vertical_offset(value: float) -> void:
	offset_y = value
	_sync_position()

func _sync_position() -> void:
	var owner_2d := get_parent() as Node2D
	if owner_2d == null or not is_inside_tree():
		position = Vector2(0.0, offset_y)
		return
	var hybrid_view := ProjectedUi.get_hybrid_view(get_tree())
	if hybrid_view == null:
		position = Vector2(0.0, offset_y)
		global_rotation = 0.0
		return
	var anchor_canvas := hybrid_view.call("project_world_to_canvas", owner_2d.global_position, get_viewport()) as Vector2
	var canvas := get_viewport().get_canvas_transform()
	global_position = anchor_canvas + canvas.basis_xform_inv(Vector2(0.0, offset_y))
	global_rotation = 0.0

func set_max_hp(value: int) -> void:
	var max_value: int = max(1, value)
	bar.max_value = float(max_value)
	if bar.value > bar.max_value:
		bar.value = bar.max_value

func set_hp(value: int) -> void:
	bar.value = clampf(float(value), 0.0, bar.max_value)

func show_for(duration_sec: float) -> void:
	visible = true
	hide_timer.stop()
	hide_timer.wait_time = maxf(0.05, duration_sec)
	hide_timer.start()

func hide_immediately() -> void:
	hide_timer.stop()
	visible = false

func _on_hide_timer_timeout() -> void:
	visible = false
