extends Control
class_name WeaponSkillChargeTrack

@export var current_charges := 0:
	set(value):
		current_charges = maxi(value, 0)
		queue_redraw()
@export var max_charges := 0:
	set(value):
		max_charges = maxi(value, 0)
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var cycle_progress := 0.0:
	set(value):
		cycle_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var show_cycle_progress := false:
	set(value):
		show_cycle_progress = value
		queue_redraw()
@export var filled_color := Color(1.0, 0.86, 0.26, 0.98):
	set(value):
		filled_color = value
		queue_redraw()
@export var empty_color := Color(0.23, 0.24, 0.26, 0.72):
	set(value):
		empty_color = value
		queue_redraw()
@export var outline_color := Color(0.05, 0.05, 0.05, 0.88):
	set(value):
		outline_color = value
		queue_redraw()
@export var cycle_color := Color(0.62, 1.0, 1.0, 1.0):
	set(value):
		cycle_color = value
		queue_redraw()
@export var cycle_track_color := Color(0.08, 0.48, 0.56, 1.0):
	set(value):
		cycle_track_color = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var trigger_flash := 0.0:
	set(value):
		trigger_flash = clampf(value, 0.0, 1.0)
		queue_redraw()

const HORIZONTAL_PADDING := 2.0
const SEGMENT_GAP := 5.0
const CHARGE_HEIGHT := 6.0
const CYCLE_HEIGHT := 3.0
const CYCLE_GAP := 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_segment_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var count := maxi(max_charges, 0)
	if count <= 1:
		return rects
	var usable_width := maxf(size.x - HORIZONTAL_PADDING * 2.0, 1.0)
	var segment_width := maxf(
		(usable_width - SEGMENT_GAP * float(count - 1)) / float(count),
		1.0
	)
	var occupied_height := CHARGE_HEIGHT
	if show_cycle_progress:
		occupied_height += CYCLE_GAP + CYCLE_HEIGHT
	var top := floorf((size.y - occupied_height) * 0.5)
	for index in range(count):
		rects.append(Rect2(
			Vector2(HORIZONTAL_PADDING + float(index) * (segment_width + SEGMENT_GAP), top),
			Vector2(segment_width, CHARGE_HEIGHT)
		))
	return rects

func get_cycle_rect() -> Rect2:
	if not show_cycle_progress or max_charges <= 1:
		return Rect2()
	var rects := get_segment_rects()
	if rects.is_empty():
		return Rect2()
	var first: Rect2 = rects.front()
	var last: Rect2 = rects.back()
	return Rect2(
		Vector2(first.position.x, first.end.y + CYCLE_GAP),
		Vector2(last.end.x - first.position.x, CYCLE_HEIGHT)
	)

func get_segment_fill_ratios() -> Array[float]:
	var ratios: Array[float] = []
	var filled_count := clampi(current_charges, 0, max_charges)
	for index in range(maxi(max_charges, 0)):
		ratios.append(1.0 if index < filled_count else 0.0)
	return ratios

func _draw() -> void:
	var rects := get_segment_rects()
	if rects.is_empty():
		return
	var fill_ratios := get_segment_fill_ratios()
	for index in range(rects.size()):
		var rect := rects[index]
		_draw_capsule(rect, outline_color)
		var inner := rect.grow(-1.0)
		_draw_capsule(inner, empty_color)
		var fill_ratio := fill_ratios[index]
		if fill_ratio > 0.0:
			_draw_capsule(inner, filled_color)
		if trigger_flash > 0.001:
			_draw_capsule(
				inner,
				Color(1.0, 0.98, 0.78, trigger_flash * 0.82)
			)
	var cycle_rect := get_cycle_rect()
	if cycle_rect.has_area():
		_draw_capsule(cycle_rect, cycle_track_color)
		if cycle_progress > 0.0:
			draw_rect(
				Rect2(
					cycle_rect.position,
					Vector2(cycle_rect.size.x * cycle_progress, cycle_rect.size.y)
				),
				cycle_color
			)

func _draw_capsule(rect: Rect2, color: Color) -> void:
	if not rect.has_area():
		return
	var radius := minf(rect.size.y * 0.5, rect.size.x * 0.5)
	var body_width := maxf(rect.size.x - radius * 2.0, 0.0)
	if body_width > 0.0:
		draw_rect(
			Rect2(
				rect.position + Vector2(radius, 0.0),
				Vector2(body_width, rect.size.y)
			),
			color
		)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
