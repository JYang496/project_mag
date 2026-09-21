extends Node2D
class_name TargetWarning

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const FEEDBACK_SPEC := preload("res://Combat/visual/combat_feedback_spec.gd")

enum VisualPreset {
	BASIC = 0,
	DODGE_STYLE = 1,
}

@export var visual_preset: VisualPreset = VisualPreset.BASIC
@export var duration: float = 0.8
@export var radius: float = 52.0
@export var fill_color: Color = Color(PALETTE.ENEMY_PRIMARY, 0.18)
@export var line_color: Color = Color(PALETTE.ENEMY_PRIMARY, 0.96)
@export var line_width: float = 4.0
@export var show_countdown: bool = true
@export var reveal_from_center: bool = true
@export var danger_level: CombatFeedbackSpec.DangerLevel = CombatFeedbackSpec.DangerLevel.DANGER

var _elapsed: float = 0.0
var _fill_polygon: Polygon2D = null
var _outline_line: Line2D = null
var _countdown_label: Label = null
var _hybrid_ground_registered := false

func _ready() -> void:
	add_to_group("enemy_runtime_cleanup")
	add_to_group(&"hybrid_ground_warning_circle")
	z_as_relative = true
	z_index = -2
	if visual_preset == VisualPreset.DODGE_STYLE:
		_build_dodge_style_visuals()
	set_process(true)
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()
	else:
		_update_dodge_style_progress()
	_update_countdown_label()
	call_deferred("_register_with_hybrid_ground")

func _register_with_hybrid_ground() -> void:
	if HybridGroundRegistration.register(self, &"register_warning_circle"):
		_hybrid_ground_registered = true
		visible = false

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)

func _process(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= maxf(duration, 0.01):
		queue_free()
		return
	# Hybrid Ground reads the timing accessors directly. Updating hidden Canvas
	# geometry and labels here would duplicate the same animation every frame.
	if _hybrid_ground_registered:
		return
	if visual_preset == VisualPreset.BASIC:
		queue_redraw()
	else:
		_update_dodge_style_progress()
	_update_countdown_label()

func get_warning_progress() -> float:
	if not reveal_from_center:
		return 1.0
	return clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)

func get_warning_phase_progress() -> float:
	return clampf(_elapsed / maxf(duration, 0.01), 0.0, 1.0)

func get_warning_fill_alpha_multiplier() -> float:
	var progress := get_warning_phase_progress()
	if get_meta(&"player_attack_range", false):
		return 0.78
	if progress < FEEDBACK_SPEC.WARNING_CONFIRM_PHASE:
		return lerpf(0.72, 0.90, progress / FEEDBACK_SPEC.WARNING_CONFIRM_PHASE)
	if progress < FEEDBACK_SPEC.WARNING_URGENT_PHASE:
		return 0.82
	var urgent := inverse_lerp(FEEDBACK_SPEC.WARNING_URGENT_PHASE, 1.0, progress)
	return lerpf(0.88, 1.0, sin(urgent * PI * 3.0) * 0.5 + 0.5)

func get_warning_outline_alpha_multiplier() -> float:
	if get_meta(&"player_attack_range", false):
		return 0.62
	var progress := get_warning_phase_progress()
	if progress < FEEDBACK_SPEC.WARNING_URGENT_PHASE:
		return 0.88
	var urgent := inverse_lerp(FEEDBACK_SPEC.WARNING_URGENT_PHASE, 1.0, progress)
	return lerpf(0.82, 1.0, sin(urgent * PI * 4.0) * 0.5 + 0.5)

func configure_enemy_danger(
	requested_duration: float,
	requested_radius: float,
	requested_level: CombatFeedbackSpec.DangerLevel = CombatFeedbackSpec.DangerLevel.DANGER
) -> void:
	# Match the owning attack exactly; the shared phase ratios normalize cadence
	# without moving the gameplay impact frame.
	duration = maxf(requested_duration, 0.05)
	radius = maxf(requested_radius, 8.0)
	danger_level = requested_level
	visual_preset = VisualPreset.DODGE_STYLE
	reveal_from_center = false
	show_countdown = false
	var semantic_color := FEEDBACK_SPEC.danger_color(danger_level)
	fill_color = Color(semantic_color, 0.16)
	line_color = Color(
		FEEDBACK_SPEC.COLOR_WARNING if danger_level == CombatFeedbackSpec.DangerLevel.DANGER else semantic_color,
		0.98
	)
	line_width = 3.0 if danger_level == CombatFeedbackSpec.DangerLevel.CAUTION else 4.0

func configure_player_preview(requested_duration: float, requested_radius: float) -> void:
	duration = maxf(requested_duration, 0.05)
	radius = maxf(requested_radius, 1.0)
	set_meta(&"player_attack_range", true)
	visual_preset = VisualPreset.BASIC
	reveal_from_center = false
	show_countdown = false
	fill_color = PALETTE.PLAYER_RANGE_FILL
	line_color = PALETTE.PLAYER_RANGE_OUTLINE
	line_width = PALETTE.PLAYER_RANGE_LINE_WIDTH

func get_warning_remaining() -> float:
	return maxf(duration - _elapsed, 0.0)

func get_warning_countdown_text() -> String:
	var tenths_remaining := ceili(get_warning_remaining() * 10.0)
	return "%.1f" % (float(tenths_remaining) / 10.0)

func _draw() -> void:
	if visual_preset != VisualPreset.BASIC:
		return
	var phase_progress := get_warning_phase_progress()
	var alpha_fill := Color(fill_color, fill_color.a * get_warning_fill_alpha_multiplier())
	var alpha_line := Color(line_color, line_color.a * get_warning_outline_alpha_multiplier())
	draw_circle(Vector2.ZERO, radius * get_warning_progress(), alpha_fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, alpha_line, maxf(roundf(line_width), 1.0), false)
	if not get_meta(&"player_attack_range", false):
		var sweep_radius := lerpf(radius * 0.82, radius * 0.16, phase_progress)
		draw_arc(Vector2.ZERO, sweep_radius, 0.0, TAU, 24, alpha_line, 2.0, false)
		_draw_danger_ticks(alpha_line, phase_progress)

func _draw_danger_ticks(color: Color, progress: float) -> void:
	var tick_length := 7.0 if progress < FEEDBACK_SPEC.WARNING_URGENT_PHASE else 11.0
	for index in range(4):
		var direction := Vector2.from_angle(float(index) * PI * 0.5)
		var outer := direction * (radius + 2.0)
		draw_line(outer - direction * tick_length, outer, color, 2.0, false)

func _build_dodge_style_visuals() -> void:
	var safe_radius := maxf(radius, 8.0)
	_fill_polygon = Polygon2D.new()
	_fill_polygon.name = "DangerFill"
	_fill_polygon.color = fill_color
	_fill_polygon.polygon = _build_circle_polygon(safe_radius, 28)
	_fill_polygon.scale = Vector2.ZERO
	add_child(_fill_polygon)

	_outline_line = Line2D.new()
	_outline_line.name = "DamageBoundary"
	_outline_line.width = maxf(line_width + 1.0, 2.0)
	_outline_line.default_color = line_color
	_outline_line.closed = true
	_outline_line.points = _build_circle_polygon(safe_radius, 28)
	_outline_line.antialiased = false
	add_child(_outline_line)

	if show_countdown:
		_countdown_label = Label.new()
		_countdown_label.name = "CountdownLabel"
		_countdown_label.position = Vector2(-28.0, -16.0)
		_countdown_label.size = Vector2(56.0, 32.0)
		_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_countdown_label.add_theme_font_size_override("font_size", 18)
		_countdown_label.add_theme_color_override("font_color", Color.WHITE)
		_countdown_label.add_theme_color_override("font_outline_color", Color(0.10, 0.02, 0.03, 0.94))
		_countdown_label.add_theme_constant_override("outline_size", 5)
		_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_countdown_label)
		_update_countdown_label()

	_update_dodge_style_progress()

func _update_dodge_style_progress() -> void:
	if _fill_polygon == null:
		return
	var progress := get_warning_progress()
	var phase_progress := get_warning_phase_progress()
	_fill_polygon.scale = Vector2.ONE * progress
	_fill_polygon.color = Color(fill_color, fill_color.a * get_warning_fill_alpha_multiplier())
	if _outline_line != null:
		_outline_line.default_color = Color(line_color, line_color.a * get_warning_outline_alpha_multiplier())
		_outline_line.width = line_width + (1.0 if phase_progress >= FEEDBACK_SPEC.WARNING_URGENT_PHASE else 0.0)

func _update_countdown_label() -> void:
	if _countdown_label != null:
		_countdown_label.text = get_warning_countdown_text()

func _build_circle_polygon(target_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(segments, 8)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * target_radius)
	return points
