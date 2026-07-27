extends Node2D
class_name PlayerDamageImpactRing

var _progress: float = 0.0
var _color := Color(1.0, 0.22, 0.12, 0.9)
var _radius: float = 34.0


func setup(damage_type: StringName, severity: float, is_periodic: bool) -> void:
	_color = _color_for_damage_type(damage_type)
	_radius = lerpf(24.0, 48.0, clampf(severity, 0.0, 1.0))
	if is_periodic:
		_radius *= 0.65
		_color.a *= 0.55


func _ready() -> void:
	z_index = 20
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_progress, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var radius := lerpf(8.0, _radius, _progress)
	var alpha := (1.0 - _progress) * _color.a
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(_color.r, _color.g, _color.b, alpha), 2.5, true)


func _color_for_damage_type(damage_type: StringName) -> Color:
	match Attack.normalize_damage_type(damage_type):
		Attack.TYPE_FIRE:
			return Color(1.0, 0.28, 0.04, 0.92)
		Attack.TYPE_FREEZE:
			return Color(0.25, 0.85, 1.0, 0.88)
		Attack.TYPE_ENERGY:
			return Color(0.72, 0.38, 1.0, 0.90)
		_:
			return Color(1.0, 0.18, 0.10, 0.90)
