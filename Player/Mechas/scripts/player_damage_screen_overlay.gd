extends Control
class_name PlayerDamageScreenOverlay

var _strength: float = 0.0
var _direction := Vector2.ZERO
var _damage_color := Color(1.0, 0.08, 0.04, 1.0)
var _fade_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play_hit(direction: Vector2, strength: float, damage_type: StringName, is_periodic: bool) -> void:
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO
	_damage_color = _color_for_damage_type(damage_type)
	var periodic_mul := 0.42 if is_periodic else 1.0
	_strength = maxf(_strength, clampf(strength * periodic_mul, 0.0, 1.0))
	visible = true
	queue_redraw()
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_method(_set_strength, _strength, 0.0, 0.34 if not is_periodic else 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.finished.connect(hide, CONNECT_ONE_SHOT)


func get_feedback_strength() -> float:
	return _strength


func get_feedback_direction() -> Vector2:
	return _direction


func shutdown() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
	_strength = 0.0
	visible = false


func _set_strength(value: float) -> void:
	_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.001:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var edge_depth := minf(viewport_size.x, viewport_size.y) * 0.18
	var left_weight := 0.18 if _direction == Vector2.ZERO else maxf(0.0, -_direction.x)
	var right_weight := 0.18 if _direction == Vector2.ZERO else maxf(0.0, _direction.x)
	var top_weight := 0.18 if _direction == Vector2.ZERO else maxf(0.0, -_direction.y)
	var bottom_weight := 0.18 if _direction == Vector2.ZERO else maxf(0.0, _direction.y)
	for step in range(8):
		var t := float(step) / 8.0
		var band_alpha := _strength * 0.11 * pow(1.0 - t, 2.0)
		var band := maxf(1.0, edge_depth / 8.0)
		var inset := edge_depth * t
		_draw_edge_band(Rect2(Vector2(inset, 0.0), Vector2(band, viewport_size.y)), band_alpha * left_weight)
		_draw_edge_band(Rect2(Vector2(viewport_size.x - inset - band, 0.0), Vector2(band, viewport_size.y)), band_alpha * right_weight)
		_draw_edge_band(Rect2(Vector2(0.0, inset), Vector2(viewport_size.x, band)), band_alpha * top_weight)
		_draw_edge_band(Rect2(Vector2(0.0, viewport_size.y - inset - band), Vector2(viewport_size.x, band)), band_alpha * bottom_weight)


func _draw_edge_band(rect: Rect2, alpha: float) -> void:
	draw_rect(rect, Color(_damage_color.r, _damage_color.g, _damage_color.b, alpha), true)


func _color_for_damage_type(damage_type: StringName) -> Color:
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			return Color(1.0, 0.12, 0.025, 1.0)
		Attack.TYPE_FREEZE:
			return Color(0.22, 0.72, 1.0, 1.0)
		Attack.TYPE_ENERGY:
			return Color(0.64, 0.26, 1.0, 1.0)
		_:
			return Color(1.0, 0.055, 0.035, 1.0)


func _exit_tree() -> void:
	shutdown()
