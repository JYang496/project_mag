extends Node2D
class_name EnemyHpBar

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const MAX_SIMULTANEOUS_BARS := 8

static var _visible_bars: Array[WeakRef] = []

@export var offset_y: float = -30.0

@onready var bar: ProgressBar = $Bar
@onready var hide_timer: Timer = $HideTimer

func _ready() -> void:
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 128
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
		bar.call("set_target_value", bar.max_value, true)

func set_hp(value: int) -> void:
	bar.call("set_target_value", clampf(float(value), 0.0, bar.max_value))

func show_for(duration_sec: float) -> void:
	_prune_visible_bars()
	_unregister_visible_bar()
	while _visible_bars.size() >= MAX_SIMULTANEOUS_BARS:
		var oldest_ref: WeakRef = _visible_bars.pop_front()
		var oldest: EnemyHpBar = oldest_ref.get_ref() as EnemyHpBar
		if oldest != null and is_instance_valid(oldest):
			oldest.hide_immediately()
	_visible_bars.append(weakref(self))
	visible = true
	hide_timer.stop()
	hide_timer.wait_time = maxf(0.05, duration_sec)
	hide_timer.start()

func hide_immediately() -> void:
	hide_timer.stop()
	visible = false
	_unregister_visible_bar()

func _on_hide_timer_timeout() -> void:
	hide_immediately()

func _exit_tree() -> void:
	_unregister_visible_bar()

func _prune_visible_bars() -> void:
	for index in range(_visible_bars.size() - 1, -1, -1):
		var candidate: EnemyHpBar = _visible_bars[index].get_ref() as EnemyHpBar
		if candidate == null or not is_instance_valid(candidate) or not candidate.visible:
			_visible_bars.remove_at(index)

func _unregister_visible_bar() -> void:
	for index in range(_visible_bars.size() - 1, -1, -1):
		var candidate: EnemyHpBar = _visible_bars[index].get_ref() as EnemyHpBar
		if candidate == null or not is_instance_valid(candidate) or candidate == self:
			_visible_bars.remove_at(index)
