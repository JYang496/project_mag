extends Control
class_name WeaponAmmoColumn

const SEGMENT_COUNT := 8
const INNER_MARGIN := 2.0
const SEGMENT_GAP := 2.0

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var fill_color := Color(0.33, 0.66, 1.0, 0.95):
	set(value):
		fill_color = value
		queue_redraw()
var track_color := Color(0.11, 0.20, 0.25, 0.92):
	set(value):
		track_color = value
		queue_redraw()


func set_ammo_state(value: float, color: Color, base: Color) -> void:
	progress = value
	fill_color = color
	track_color = base


func get_segment_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var inner_height := maxf(size.y - INNER_MARGIN * 2.0, 1.0)
	var total_gap := SEGMENT_GAP * float(SEGMENT_COUNT - 1)
	var segment_height := floorf(maxf(inner_height - total_gap, 1.0) / float(SEGMENT_COUNT))
	var used_height := segment_height * SEGMENT_COUNT + total_gap
	var start_y := floorf((size.y - used_height) * 0.5)
	for index in range(SEGMENT_COUNT):
		var bottom_index := SEGMENT_COUNT - 1 - index
		var y := start_y + float(bottom_index) * (segment_height + SEGMENT_GAP)
		rects.append(Rect2(Vector2(INNER_MARGIN, y), Vector2(maxf(size.x - INNER_MARGIN * 2.0, 1.0), segment_height)))
	return rects


func get_segment_fill_ratios() -> Array[float]:
	var ratios: Array[float] = []
	var scaled := progress * float(SEGMENT_COUNT)
	for index in range(SEGMENT_COUNT):
		ratios.append(clampf(scaled - float(index), 0.0, 1.0))
	return ratios


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.05, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.72, 0.84, 0.76), false, 1.0)
	var rects := get_segment_rects()
	var fill_ratios := get_segment_fill_ratios()
	var highest_filled_index := mini(ceili(progress * float(SEGMENT_COUNT)) - 1, SEGMENT_COUNT - 1)
	for index in range(rects.size()):
		var segment := rects[index]
		draw_rect(segment, track_color, true)
		var fill_ratio := fill_ratios[index]
		if fill_ratio <= 0.0:
			continue
		var fill_height := maxf(floorf(segment.size.y * fill_ratio), 1.0)
		var fill_rect := Rect2(
			Vector2(segment.position.x, segment.end.y - fill_height),
			Vector2(segment.size.x, fill_height)
		)
		draw_rect(fill_rect, fill_color, true)
		if index == highest_filled_index:
			draw_line(fill_rect.position, Vector2(fill_rect.end.x, fill_rect.position.y), Color(fill_color.r, fill_color.g, fill_color.b, 0.92), 1.0)
