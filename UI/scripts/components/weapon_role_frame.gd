extends Control
## Main-hand outline doubles as the magazine-capacity track.
## The short lower-right gap follows the smaller skill disk junction.
## Magazine progress still fills clockwise along the remaining outline.
const AMMO_ARC_START := deg_to_rad(67.0)
const AMMO_ARC_END := TAU + deg_to_rad(23.0)
const MAINHAND_AMMO_COLOR := Color("73e7ef")
const MAINHAND_RING_COLOR := Color("9af6ff")
const MAINHAND_RING_GLOW := Color(0.45, 0.94, 1.0, 0.18)
const MAINHAND_MARKER_SHADOW := Color(0.015, 0.03, 0.04, 0.98)
const MAINHAND_MARKER_COLOR := Color("d3fbff")

var selected := false:
	set(value):
		if selected == value:
			return
		selected = value
		queue_redraw()

var ammo_visible := false
var ammo_progress := 0.0
var ammo_fill_color := MAINHAND_AMMO_COLOR
var ammo_track_color := Color(0.12, 0.30, 0.34, 0.72)


func set_ammo_state(visible_value: bool, progress_value: float, fill: Color, track: Color) -> void:
	var next_progress := clampf(progress_value, 0.0, 1.0)
	if ammo_visible == visible_value \
			and is_equal_approx(ammo_progress, next_progress) \
			and ammo_fill_color == fill \
			and ammo_track_color == track:
		return
	ammo_visible = visible_value
	ammo_progress = next_progress
	ammo_fill_color = fill
	ammo_track_color = track
	queue_redraw()


func _draw() -> void:
	var center := Vector2(38, 36)
	if selected:
		_draw_mainhand_selection(center)
		if ammo_visible:
			_draw_mainhand_ammo_arc(center)
	else:
		draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.015,0.03,0.04,0.92), 5.0, true)
		draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.58,0.68,0.70,0.58), 1.0, true)


func _draw_mainhand_selection(center: Vector2) -> void:
	# Selection remains legible even when the weapon has no magazine resource.
	draw_arc(center, 34, AMMO_ARC_START, AMMO_ARC_END, 80, MAINHAND_RING_GLOW, 9.0, true)
	draw_arc(center, 34, AMMO_ARC_START, AMMO_ARC_END, 80, MAINHAND_MARKER_SHADOW, 6.0, true)
	draw_arc(center, 34, AMMO_ARC_START, AMMO_ARC_END, 80, MAINHAND_RING_COLOR, 4.0, true)

	# A larger high-contrast pointer makes the active slot readable at a glance.
	draw_colored_polygon(
		PackedVector2Array([Vector2(28, -8), Vector2(48, -8), Vector2(38, 3)]),
		MAINHAND_MARKER_SHADOW
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(31, -6), Vector2(45, -6), Vector2(38, 1)]),
		MAINHAND_MARKER_COLOR
	)


func _draw_mainhand_ammo_arc(center: Vector2) -> void:
	# Ammo is a separate inner track, so an empty magazine cannot erase selection.
	draw_arc(center, 30, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.015, 0.03, 0.04, 0.92), 4.0, true)
	draw_arc(center, 30, AMMO_ARC_START, AMMO_ARC_END, 80, ammo_track_color, 2.0, true)
	if ammo_progress <= 0.001:
		return
	var fill_end := lerpf(AMMO_ARC_START, AMMO_ARC_END, ammo_progress)
	draw_arc(center, 30, AMMO_ARC_START, fill_end, 80, Color(ammo_fill_color, 0.16), 5.0, true)
	draw_arc(center, 30, AMMO_ARC_START, fill_end, 80, ammo_fill_color, 2.0, true)
	var tip := center + Vector2.from_angle(fill_end) * 30.0
	draw_circle(tip, 1.75, ammo_fill_color.lightened(0.24))
