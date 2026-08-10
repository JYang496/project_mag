extends "res://Visual/Oblique/billboard_visual_2d.gd"
class_name AffiliationMarker

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
var _hybrid_config: Dictionary = {}
var _hybrid_visual_version := 0

enum MarkerShape {
	PLAYER_RING,
	ENEMY_BRACKETS,
	FRIENDLY_FRAME,
	NEUTRAL_DASHES,
}

enum MarkerRank {
	STANDARD,
	ELITE,
}

@export var marker_shape: MarkerShape = MarkerShape.ENEMY_BRACKETS:
	set(value):
		marker_shape = value
		queue_redraw()
@export var marker_color: Color = PALETTE.ENEMY_PRIMARY:
	set(value):
		marker_color = value
		queue_redraw()
@export_range(8.0, 48.0, 1.0) var radius := 20.0:
	set(value):
		radius = value
		queue_redraw()
@export var ground_footprint_size := Vector2.ZERO:
	set(value):
		ground_footprint_size = value.abs()
		queue_redraw()
@export_range(0.5, 3.0, 0.25) var line_width := 1.0:
	set(value):
		line_width = value
		queue_redraw()
@export_range(0.1, 1.2, 0.05) var arc_length := 0.46:
	set(value):
		arc_length = value
		queue_redraw()
@export var marker_rank: MarkerRank = MarkerRank.STANDARD:
	set(value):
		marker_rank = value
		queue_redraw()


func _ready() -> void:
	# Affiliation markers describe a ground footprint. Their explicit ellipse
	# already lives in ground space, so upright billboard compensation must not
	# reshape it a second time in the 2D fallback.
	enabled = false
	# Keep the marker immediately behind its projected owner while sharing the
	# same depth bucket as the rest of the billboard visuals.
	depth_sort_offset = -1
	super._ready()
	if _get_hybrid_view() == null:
		z_as_relative = true
		z_index = -1
	queue_redraw()
	set_meta(&"hybrid_ground_visible", visible)
	call_deferred("sync_to_ground_shadow")


func _process(delta: float) -> void:
	super._process(delta)


func _register_with_hybrid_ground() -> void:
	if not is_inside_tree():
		return
	if not has_meta(&"hybrid_ground_visible"):
		set_meta(&"hybrid_ground_visible", visible)
	if HybridGroundRegistration.register(self, &"register_affiliation_marker"):
		visible = false


func sync_to_ground_shadow() -> void:
	if not is_inside_tree():
		return
	var unit_owner := get_parent() as Node2D
	var shadow := unit_owner.get_node_or_null("GroundShadow") as CanvasItem if unit_owner != null else null
	if shadow != null:
		var shadow_2d := shadow as Node2D
		if shadow_2d != null:
			set_logical_local_position(shadow_2d.position)
		var shadow_size := _get_shadow_visual_size(shadow)
		if shadow_size.x > 0.0 and shadow_size.y > 0.0:
			ground_footprint_size = shadow_size
	_register_with_hybrid_ground()


func _get_shadow_visual_size(shadow: CanvasItem) -> Vector2:
	if shadow is Sprite2D:
		var sprite := shadow as Sprite2D
		if sprite.texture != null:
			return sprite.texture.get_size() * sprite.scale.abs()
	if shadow is Polygon2D:
		var polygon := shadow as Polygon2D
		if not polygon.polygon.is_empty():
			var bounds := Rect2(polygon.polygon[0], Vector2.ZERO)
			for point in polygon.polygon:
				bounds = bounds.expand(point)
			return bounds.size * polygon.scale.abs()
	return Vector2.ZERO


func get_hybrid_ground_marker_config() -> Dictionary:
	var changed := _set_hybrid_value(&"local_anchor", _base_transform.origin)
	changed = _set_hybrid_value(&"footprint_size", _get_effective_footprint_size()) or changed
	changed = _set_hybrid_value(&"line_width", line_width) or changed
	changed = _set_hybrid_value(&"arc_length", arc_length) or changed
	changed = _set_hybrid_value(&"color", marker_color) or changed
	changed = _set_hybrid_value(&"marker_shape", marker_shape) or changed
	changed = _set_hybrid_value(&"marker_rank", marker_rank) or changed
	changed = _set_hybrid_value(&"visible", bool(get_meta(&"hybrid_ground_visible", true))) or changed
	if changed:
		_hybrid_visual_version += 1
	_hybrid_config["visual_version"] = _hybrid_visual_version
	return _hybrid_config


func _set_hybrid_value(key: StringName, value: Variant) -> bool:
	if _hybrid_config.has(key) and _hybrid_config[key] == value:
		return false
	_hybrid_config[key] = value
	return true


func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
	super._exit_tree()


func _draw() -> void:
	match marker_shape:
		MarkerShape.PLAYER_RING:
			_draw_player_ring()
		MarkerShape.FRIENDLY_FRAME:
			_draw_friendly_frame()
		MarkerShape.NEUTRAL_DASHES:
			_draw_neutral_dashes()
		_:
			_draw_enemy_brackets()


func _draw_player_ring() -> void:
	var gap := 0.54
	_draw_ellipse_arc(
		-PI * 0.5 + gap,
		PI * 1.5 - gap,
		40
	)
	var radii := _get_effective_footprint_size() * 0.5
	draw_circle(Vector2(0.0, -radii.y), line_width * 0.75, PALETTE.PLAYER_CORE)


func _draw_enemy_brackets() -> void:
	for index in range(4):
		var center_angle := PI * 0.25 + float(index) * PI * 0.5
		_draw_ellipse_arc(
			center_angle - arc_length * 0.5,
			center_angle + arc_length * 0.5,
			7
		)
		var radii := _get_effective_footprint_size() * 0.5
		var tip := Vector2(cos(center_angle) * radii.x, sin(center_angle) * radii.y)
		var inward := -tip.normalized() * 4.0
		draw_line(tip, tip + inward, marker_color, line_width, true)
	if marker_rank == MarkerRank.ELITE:
		_draw_elite_accents()


func _draw_elite_accents() -> void:
	var radii := _get_effective_footprint_size() * 0.62
	for index in range(4):
		var angle := float(index) * PI * 0.5
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-radial.y, radial.x)
		var center := radial * radii
		draw_polyline(
			PackedVector2Array([center - tangent * 3.0, center, center + tangent * 3.0]),
			marker_color,
			line_width,
			true
		)


func _draw_friendly_frame() -> void:
	for index in range(4):
		var center_angle := PI * 0.25 + float(index) * PI * 0.5
		_draw_ellipse_arc(center_angle - 0.58, center_angle + 0.58, 10)


func _draw_neutral_dashes() -> void:
	for index in range(8):
		var start_angle := float(index) * TAU / 8.0
		_draw_ellipse_arc(start_angle, start_angle + 0.34, 4)


func _draw_ellipse_arc(start_angle: float, end_angle: float, point_count: int) -> void:
	var radii := _get_effective_footprint_size() * 0.5
	var points := PackedVector2Array()
	for index in range(maxi(point_count, 2)):
		var weight := float(index) / float(maxi(point_count - 1, 1))
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, marker_color, line_width, true)


func _get_effective_footprint_size() -> Vector2:
	if ground_footprint_size.x > 0.0 and ground_footprint_size.y > 0.0:
		return ground_footprint_size
	return Vector2.ONE * radius * 2.0


func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = marker_color
	style.set_border_width_all(int(ceilf(line_width)))
	style.set_corner_radius_all(5)
	return style
