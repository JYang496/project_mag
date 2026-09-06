extends Control
## Main-hand outline doubles as the magazine-capacity track.
## The short lower-right gap follows the smaller skill disk junction.
## Magazine progress still fills clockwise along the remaining outline.
const AMMO_ARC_START := deg_to_rad(67.0)
const AMMO_ARC_END := TAU + deg_to_rad(23.0)
const MAINHAND_AMMO_COLOR := Color("73e7ef")

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
	if selected and ammo_visible:
		_draw_mainhand_ammo_arc(center)
	else:
		draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.015,0.03,0.04,0.92), 5.0, true)
		draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.58,0.68,0.70,0.58), 1.0, true)
	if selected:
		draw_colored_polygon(PackedVector2Array([Vector2(31,-5),Vector2(45,-5),Vector2(38,2)]),Color(0.015,0.03,0.04,0.95))
		draw_colored_polygon(PackedVector2Array([Vector2(33,-4),Vector2(43,-4),Vector2(38,0)]),Color("d3fbff"))


func _draw_mainhand_ammo_arc(center: Vector2) -> void:
	draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, Color(0.015, 0.03, 0.04, 0.92), 6.0, true)
	draw_arc(center, 32, AMMO_ARC_START, AMMO_ARC_END, 80, ammo_track_color, 2.5, true)
	if ammo_progress <= 0.001:
		return
	var fill_end := lerpf(AMMO_ARC_START, AMMO_ARC_END, ammo_progress)
	draw_arc(center, 33, AMMO_ARC_START, fill_end, 80, Color(ammo_fill_color, 0.14), 7.0, true)
	draw_arc(center, 32, AMMO_ARC_START, fill_end, 80, ammo_fill_color, 2.5, true)
	var tip := center + Vector2.from_angle(fill_end) * 32.0
	draw_circle(tip, 1.75, ammo_fill_color.lightened(0.24))
