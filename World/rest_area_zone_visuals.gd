extends Node2D

const ZONE_ID_PURCHASE := 0
const ZONE_ID_UPGRADE := 1
const ZONE_ID_WAREHOUSE := 2
const ZONE_ID_BOARD_EDIT := 6
const ZONE_ID_START_BATTLE := 4
const VISUAL_ZONE_IDS: Array[int] = [
	ZONE_ID_PURCHASE,
	ZONE_ID_UPGRADE,
	ZONE_ID_WAREHOUSE,
	ZONE_ID_BOARD_EDIT,
	ZONE_ID_START_BATTLE,
]

const ZONE_COLORS := {
	ZONE_ID_PURCHASE: Color(1.0, 0.76, 0.22, 1.0),
	ZONE_ID_UPGRADE: Color(1.0, 0.38, 0.18, 1.0),
	ZONE_ID_WAREHOUSE: Color(0.38, 0.68, 1.0, 1.0),
	ZONE_ID_BOARD_EDIT: Color(0.34, 1.0, 0.78, 1.0),
	ZONE_ID_START_BATTLE: Color(0.42, 1.0, 0.48, 1.0),
}

var _pulse_time := 0.0

func _ready() -> void:
	z_as_relative = true
	z_index = 8
	set_process(true)

func _process(delta: float) -> void:
	_pulse_time = fmod(_pulse_time + maxf(delta, 0.0), TAU)
	queue_redraw()

func _draw() -> void:
	var rest_area := get_parent()
	if rest_area == null or not is_instance_valid(rest_area):
		return
	if rest_area.has_method("_is_interaction_enabled") and not bool(rest_area.call("_is_interaction_enabled")):
		return
	var hover_zone_id := int(rest_area.get("hover_zone_id"))
	var selected_zone_id := int(rest_area.get("selected_zone_id"))
	for zone_id in VISUAL_ZONE_IDS:
		var zone_rect := rest_area.call("_get_zone_rect_local", zone_id) as Rect2
		if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
			continue
		var is_selected := _is_service_zone(zone_id) and zone_id == selected_zone_id
		var is_hovered := _is_service_zone(zone_id) and zone_id == hover_zone_id
		_draw_zone_visual(zone_id, zone_rect, is_hovered, is_selected)

func _is_service_zone(zone_id: int) -> bool:
	return VISUAL_ZONE_IDS.has(zone_id)

func _draw_zone_visual(zone_id: int, rect: Rect2, hovered: bool, selected: bool) -> void:
	var color := ZONE_COLORS.get(zone_id, Color.WHITE) as Color
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 2.2)
	var center := rect.get_center()
	var min_side := minf(rect.size.x, rect.size.y)
	var ground_radius := min_side * (0.30 if zone_id == ZONE_ID_START_BATTLE else 0.24)
	var alpha := 0.18
	if hovered:
		alpha = 0.34 + pulse * 0.08
	elif selected:
		alpha = 0.28
	_draw_ground_mark(zone_id, center, ground_radius, Color(color.r, color.g, color.b, alpha))
	_draw_prop(zone_id, rect, color, hovered, selected)
	_draw_icon(zone_id, center + Vector2(0.0, -min_side * 0.18), min_side * 0.10, color, hovered or selected)
	if hovered or selected:
		_draw_selection_effect(center, ground_radius, color, hovered, selected)

func _draw_ground_mark(zone_id: int, center: Vector2, radius: float, color: Color) -> void:
	match zone_id:
		ZONE_ID_START_BATTLE:
			draw_circle(center, radius, color)
			draw_arc(center, radius * 1.16, 0.0, TAU, 48, Color(color.r, color.g, color.b, color.a + 0.16), 2.0, true)
		ZONE_ID_BOARD_EDIT:
			var step := radius * 0.55
			for idx in range(-1, 2):
				draw_line(center + Vector2(idx * step, -radius), center + Vector2(idx * step, radius), color, 2.0, true)
				draw_line(center + Vector2(-radius, idx * step), center + Vector2(radius, idx * step), color, 2.0, true)
		_:
			var points: PackedVector2Array = PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
			])
			var outline: PackedVector2Array = points.duplicate()
			outline.append(points[0])
			draw_colored_polygon(points, color)
			draw_polyline(outline, Color(color.r, color.g, color.b, color.a + 0.18), 2.0, true)

func _draw_prop(zone_id: int, rect: Rect2, color: Color, hovered: bool, selected: bool) -> void:
	var center := rect.get_center()
	var min_side := minf(rect.size.x, rect.size.y)
	var prop_color := Color(color.r, color.g, color.b, 0.56 if hovered or selected else 0.40)
	var dark := Color(0.05, 0.08, 0.10, 0.55)
	match zone_id:
		ZONE_ID_PURCHASE:
			var stall := Rect2(center + Vector2(-min_side * 0.19, -min_side * 0.03), Vector2(min_side * 0.38, min_side * 0.18))
			draw_rect(stall, dark, true)
			draw_rect(stall, prop_color, false, 2.0)
			draw_line(stall.position + Vector2(0, -min_side * 0.08), stall.position + Vector2(stall.size.x, -min_side * 0.08), prop_color, 4.0, true)
		ZONE_ID_UPGRADE:
			draw_line(center + Vector2(-min_side * 0.17, min_side * 0.10), center + Vector2(min_side * 0.17, min_side * 0.10), prop_color, 5.0, true)
			draw_line(center + Vector2(0.0, min_side * 0.10), center + Vector2(0.0, -min_side * 0.08), prop_color, 4.0, true)
			draw_circle(center + Vector2(0.0, -min_side * 0.12), min_side * 0.07, Color(1.0, 0.22, 0.08, 0.38))
		ZONE_ID_WAREHOUSE:
			for offset in [Vector2(-0.13, 0.03), Vector2(0.05, 0.03), Vector2(-0.04, -0.11)]:
				var box := Rect2(center + offset * min_side, Vector2(min_side * 0.16, min_side * 0.14))
				draw_rect(box, dark, true)
				draw_rect(box, prop_color, false, 2.0)
		ZONE_ID_BOARD_EDIT:
			var desk := Rect2(center + Vector2(-min_side * 0.20, -min_side * 0.02), Vector2(min_side * 0.40, min_side * 0.16))
			draw_rect(desk, dark, true)
			draw_rect(desk, prop_color, false, 2.0)
			draw_arc(center + Vector2(0.0, -min_side * 0.04), min_side * 0.18, PI, TAU, 18, prop_color, 2.0, true)
		ZONE_ID_START_BATTLE:
			draw_line(center + Vector2(0.0, min_side * 0.18), center + Vector2(0.0, -min_side * 0.20), prop_color, 5.0, true)
			draw_circle(center + Vector2(0.0, -min_side * 0.24), min_side * 0.07, Color(color.r, color.g, color.b, 0.48))

func _draw_icon(zone_id: int, center: Vector2, size: float, color: Color, strong: bool) -> void:
	var icon_color := Color(color.r, color.g, color.b, 0.95 if strong else 0.68)
	match zone_id:
		ZONE_ID_PURCHASE:
			draw_arc(center, size, PI * 0.10, PI * 0.90, 16, icon_color, 2.0, true)
			draw_rect(Rect2(center + Vector2(-size * 0.75, -size * 0.15), Vector2(size * 1.5, size * 1.2)), icon_color, false, 2.0)
		ZONE_ID_UPGRADE:
			draw_line(center + Vector2(-size, size), center + Vector2(size, -size), icon_color, 3.0, true)
			draw_rect(Rect2(center + Vector2(size * 0.15, -size * 1.15), Vector2(size * 0.85, size * 0.45)), icon_color, false, 2.0)
		ZONE_ID_WAREHOUSE:
			draw_rect(Rect2(center - Vector2(size, size * 0.65), Vector2(size * 2.0, size * 1.3)), icon_color, false, 2.0)
			draw_line(center + Vector2(-size, -size * 0.15), center + Vector2(size, -size * 0.15), icon_color, 2.0, true)
		ZONE_ID_BOARD_EDIT:
			for idx in range(-1, 2):
				draw_line(center + Vector2(idx * size * 0.55, -size), center + Vector2(idx * size * 0.55, size), icon_color, 1.6, true)
				draw_line(center + Vector2(-size, idx * size * 0.55), center + Vector2(size, idx * size * 0.55), icon_color, 1.6, true)
		ZONE_ID_START_BATTLE:
			var points := PackedVector2Array([
				center + Vector2(-size * 0.55, -size),
				center + Vector2(size, 0.0),
				center + Vector2(-size * 0.55, size),
			])
			draw_colored_polygon(points, icon_color)

func _draw_selection_effect(center: Vector2, radius: float, color: Color, hovered: bool, selected: bool) -> void:
	var ring_alpha := 0.42
	if hovered:
		ring_alpha = 0.62
	if selected:
		ring_alpha = maxf(ring_alpha, 0.58)
	draw_arc(center, radius * 1.34, 0.0, TAU, 48, Color(color.r, color.g, color.b, ring_alpha), 2.5, true)
