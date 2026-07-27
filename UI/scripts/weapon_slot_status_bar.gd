extends Control
class_name WeaponSlotStatusBar

enum Placement { TOP, BOTTOM }

@export_range(0.0, 1.0, 0.01) var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var fill_color := Color(0.98, 0.78, 0.28, 0.95):
	set(value):
		fill_color = value
		queue_redraw()
@export var base_color := Color(0.12, 0.14, 0.16, 0.9):
	set(value):
		base_color = value
		queue_redraw()
@export var placement: Placement = Placement.BOTTOM:
	set(value):
		placement = value
		queue_redraw()
@export_range(2.0, 8.0, 0.5) var bar_height := 5.0:
	set(value):
		bar_height = value
		queue_redraw()
@export_range(4.0, 16.0, 1.0) var top_offset := 8.0:
	set(value):
		top_offset = value
		queue_redraw()
@export var ready_edge_color := Color(0.58, 0.86, 1.0, 0.0):
	set(value):
		ready_edge_color = value
		queue_redraw()

# Compatibility properties shared with the former ring indicator.
@export var line_width := 3.0
@export var padding := 10.0
@export var clockwise := true
@export var shape_mode := 0

func _draw() -> void:
	var track := get_bar_rect()
	if track.size.x <= 0.0 or track.size.y <= 0.0:
		return
	draw_rect(track, Color(0.02, 0.03, 0.04, 0.92))
	draw_rect(
		Rect2(
			track.position + Vector2.ONE,
			Vector2(maxf(track.size.x - 2.0, 0.0), maxf(track.size.y - 2.0, 0.0))
		),
		base_color
	)
	var fill_width := floorf(maxf(track.size.x - 2.0, 0.0) * progress)
	if fill_width > 0.0:
		draw_rect(
			Rect2(
				track.position + Vector2.ONE,
				Vector2(fill_width, maxf(track.size.y - 2.0, 0.0))
			),
			fill_color
		)
	if progress >= 0.999 and ready_edge_color.a > 0.0:
		draw_rect(track.grow(1.0), ready_edge_color, false, 1.0)

func get_bar_rect() -> Rect2:
	var resolved_padding := maxf(padding, 0.0)
	var left := floorf(resolved_padding)
	var right := floorf(size.x - resolved_padding)
	var bar_width := maxf(right - left, 1.0)
	var resolved_height := maxf(bar_height, 2.0)
	var top := (
		floorf(top_offset)
		if placement == Placement.TOP
		else floorf(size.y - resolved_padding - resolved_height)
	)
	return Rect2(left, top, bar_width, resolved_height)
