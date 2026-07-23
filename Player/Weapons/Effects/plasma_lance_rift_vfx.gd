extends Node2D
class_name PlasmaLanceRiftVfx

const CORE_COLOR := Color(0.82, 1.0, 1.0, 1.0)
const EDGE_COLOR := Color(0.25, 0.72, 1.0, 0.86)
const GLOW_COLOR := Color(0.55, 0.18, 1.0, 0.52)
const SPARK_COLOR := Color(0.72, 0.96, 1.0, 0.95)

var _duration: float = 0.16
var _from_pos: Vector2 = Vector2.ZERO
var _to_pos: Vector2 = Vector2.ZERO
var _width: float = 24.0


func setup(from_pos: Vector2, to_pos: Vector2, width: float, duration: float) -> void:
	_from_pos = from_pos
	_to_pos = to_pos
	_width = maxf(width, 1.0)
	_duration = maxf(duration, 0.01)


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 220
	_build_lines()
	_build_sparks()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, _duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _build_lines() -> void:
	_add_line(_width * 2.1, GLOW_COLOR, 0)
	_add_line(_width * 0.72, EDGE_COLOR, 1)
	_add_line(maxf(_width * 0.32, 3.0), CORE_COLOR, 2)


func _add_line(width: float, color: Color, order: int) -> void:
	var line := Line2D.new()
	line.name = "RiftLine%d" % order
	line.points = PackedVector2Array([_from_pos, _to_pos])
	line.width = maxf(width, 1.0)
	line.default_color = color
	line.texture_mode = Line2D.LINE_TEXTURE_NONE
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	line.begin_cap_mode = Line2D.LINE_CAP_BOX
	line.end_cap_mode = Line2D.LINE_CAP_BOX
	line.antialiased = false
	line.z_index = order
	add_child(line)
	_register_ground_line(line)


func _build_sparks() -> void:
	var delta := _to_pos - _from_pos
	var length := delta.length()
	if length <= 1.0:
		return
	var dir := delta / length
	var normal := Vector2(-dir.y, dir.x)
	var spark_count := clampi(int(length / 80.0) + 3, 3, 9)
	for i in range(spark_count):
		var t := float(i + 1) / float(spark_count + 1)
		var center := _from_pos.lerp(_to_pos, t)
		var side := -1.0 if i % 2 == 0 else 1.0
		var spark_len := minf(length * 0.06, 26.0)
		var offset := normal * side * _width * 0.36
		var tangent := dir.rotated(deg_to_rad(18.0 * side))
		var spark := Line2D.new()
		spark.name = "RiftSpark%d" % i
		spark.points = PackedVector2Array([
			center + offset - tangent * spark_len * 0.45,
			center + offset + tangent * spark_len * 0.55,
		])
		spark.width = maxf(_width * 0.08, 1.4)
		spark.default_color = SPARK_COLOR
		spark.begin_cap_mode = Line2D.LINE_CAP_BOX
		spark.end_cap_mode = Line2D.LINE_CAP_BOX
		spark.antialiased = false
		spark.z_index = 3
		add_child(spark)
		_register_ground_line(spark)

func _register_ground_line(line: Line2D) -> void:
	line.add_to_group(&"hybrid_ground_segment")
	line.set_meta("hybrid_ground_visible", true)
	if HybridGroundRegistration.register(line, &"register_ground_segment"):
		line.visible = false

func _exit_tree() -> void:
	for child in get_children():
		if child is Line2D:
			HybridGroundRegistration.unregister(child)
