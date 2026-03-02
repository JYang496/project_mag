extends Node2D
class_name SkillWarningTelegraph

@export var warning_color: Color = Color(1.0, 0.1, 0.1, 0.28)
@export var progress_color: Color = Color(1.0, 0.15, 0.15, 0.95)
@export var default_half_width: float = 32.0
@export var telegraph_z_index: int = 0

var _warning_polygon: Polygon2D
var _progress_line: Line2D
var _active := false
var _dash_distance := 0.0
var _charge_duration := 1.0
var _elapsed := 0.0
var _half_width := 32.0

func _ready() -> void:
	z_index = telegraph_z_index
	_warning_polygon = Polygon2D.new()
	_warning_polygon.name = "WarningPolygon"
	_warning_polygon.color = warning_color
	add_child(_warning_polygon)

	_progress_line = Line2D.new()
	_progress_line.name = "ChargeProgressLine"
	_progress_line.width = default_half_width * 2.0
	_progress_line.default_color = progress_color
	_progress_line.begin_cap_mode = Line2D.LINE_CAP_BOX
	_progress_line.end_cap_mode = Line2D.LINE_CAP_BOX
	add_child(_progress_line)

	visible = false

func show_dash_warning(origin: Vector2, direction: Vector2, dash_distance: float, charge_duration: float, half_width: float = -1.0) -> void:
	_active = true
	_dash_distance = maxf(0.0, dash_distance)
	_charge_duration = maxf(0.01, charge_duration)
	_elapsed = 0.0
	_half_width = default_half_width if half_width <= 0.0 else half_width
	_progress_line.width = _half_width * 2.0
	_update_pose(origin, direction)
	_update_warning_polygon()
	_update_progress_line(0.0)
	visible = true

func update_dash_warning(origin: Vector2, direction: Vector2, delta: float) -> void:
	if not _active:
		return
	_elapsed = minf(_charge_duration, _elapsed + maxf(0.0, delta))
	_update_pose(origin, direction)
	_update_progress_line(_elapsed / _charge_duration)

func clear_warning() -> void:
	_active = false
	visible = false
	_warning_polygon.polygon = PackedVector2Array()
	_progress_line.clear_points()

func _update_pose(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	var normalized := direction.normalized()
	if normalized == Vector2.ZERO:
		normalized = Vector2.RIGHT
	rotation = normalized.angle()

func _update_warning_polygon() -> void:
	_warning_polygon.polygon = PackedVector2Array([
		Vector2(0.0, -_half_width),
		Vector2(_dash_distance, -_half_width),
		Vector2(_dash_distance, _half_width),
		Vector2(0.0, _half_width),
	])

func _update_progress_line(progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var reach := _dash_distance * clamped_progress
	_progress_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(reach, 0.0),
	])
