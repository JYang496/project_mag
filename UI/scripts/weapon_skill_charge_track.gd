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
var charge_states: Array = []:
	set(value):
		charge_states = value.duplicate(true) if value != null else []
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
@export var active_color := Color(0.30, 0.92, 1.0, 1.0):
	set(value):
		active_color = value
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
var cycle_thresholds: Array = []:
	set(value):
		cycle_thresholds = value.duplicate() if value != null else []
		queue_redraw()

const HORIZONTAL_PADDING := 2.0
const SEGMENT_GAP := 6.0
const MAX_BEAN_WIDTH := 18.0
const CHARGE_HEIGHT := 8.0
const CYCLE_HEIGHT := 3.0
const CYCLE_GAP := 2.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_segment_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var count := maxi(max_charges, 0)
	if count <= 0:
		return rects
	var usable_width := maxf(size.x - HORIZONTAL_PADDING * 2.0, 1.0)
	var segment_width := minf(maxf(
		(usable_width - SEGMENT_GAP * float(count - 1)) / float(count),
		1.0
	), MAX_BEAN_WIDTH)
	var total_width := segment_width * float(count) + SEGMENT_GAP * float(count - 1)
	var start_x := HORIZONTAL_PADDING + floorf((usable_width - total_width) * 0.5)
	var occupied_height := CHARGE_HEIGHT
	if show_cycle_progress:
		occupied_height += CYCLE_GAP + CYCLE_HEIGHT
	var top := floorf((size.y - occupied_height) * 0.5)
	for index in range(count):
		rects.append(Rect2(
			Vector2(start_x + float(index) * (segment_width + SEGMENT_GAP), top),
			Vector2(segment_width, CHARGE_HEIGHT)
		))
	return rects

func get_cycle_rect() -> Rect2:
	if not show_cycle_progress or max_charges <= 0:
		return Rect2()
	var rects := get_segment_rects()
	if rects.is_empty():
		return Rect2()
	var first: Rect2 = rects.front()
	var usable_width := maxf(size.x - HORIZONTAL_PADDING * 2.0, 1.0)
	return Rect2(
		Vector2(HORIZONTAL_PADDING, first.end.y + CYCLE_GAP),
		Vector2(usable_width, CYCLE_HEIGHT)
	)

func get_segment_fill_ratios() -> Array[float]:
	var ratios: Array[float] = []
	for state in get_segment_states():
		ratios.append(0.0 if str(state) == "spent" else 1.0)
	return ratios

func get_segment_states() -> Array[String]:
	var states: Array[String] = []
	var filled_count := clampi(current_charges, 0, max_charges)
	for index in range(maxi(max_charges, 0)):
		var state := "ready" if index < filled_count else "spent"
		if index < charge_states.size():
			var requested := str(charge_states[index])
			if requested in ["ready", "active", "spent"]:
				state = requested
		states.append(state)
	return states

func _draw() -> void:
	var rects := get_segment_rects()
	if rects.is_empty():
		return
	var states := get_segment_states()
	for index in range(rects.size()):
		var rect := rects[index]
		_draw_capsule(rect, outline_color)
		var inner := rect.grow(-1.0)
		_draw_capsule(inner, empty_color)
		var state := states[index]
		if state == "ready":
			_draw_capsule(inner, filled_color)
		elif state == "active":
			_draw_capsule(inner, active_color)
			var core := inner.grow(-1.0)
			if core.has_area():
				_draw_capsule(core, active_color.lightened(0.28))
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
		for threshold_variant in cycle_thresholds:
			var threshold := clampf(float(threshold_variant), 0.0, 1.0)
			if threshold <= 0.0 or threshold >= 1.0:
				continue
			var marker_x := floorf(cycle_rect.position.x + cycle_rect.size.x * threshold)
			draw_line(
				Vector2(marker_x, cycle_rect.position.y - 1.0),
				Vector2(marker_x, cycle_rect.end.y + 1.0),
				outline_color,
				1.0
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
