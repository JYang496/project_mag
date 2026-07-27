extends RefCounted
class_name HitLabelMotion

var _tween: Tween

func restart(
	label: Control,
	style_profile: Resource,
	tier: int,
	damage_type: StringName,
	is_periodic: bool,
	is_emphasized: bool,
	fade_duration: float
) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	var life_time: float = style_profile.get_lifetime(
		tier,
		damage_type,
		is_emphasized
	)
	var target_position := clamp_to_viewport(
		label,
		(label.position + _compute_pop_offset(
			style_profile,
			tier,
			damage_type,
			is_periodic
		)).round()
	)
	label.modulate.a = 1.0
	_tween = label.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		label,
		"position",
		target_position,
		minf(life_time * 0.62, 0.28)
	)
	_tween.tween_property(label, "modulate:a", 0.0, fade_duration).set_delay(
		maxf(0.0, life_time - fade_duration)
	)
	_tween.tween_callback(label.queue_free).set_delay(life_time)

func clamp_to_viewport(label: Control, value: Vector2) -> Vector2:
	if not label.is_inside_tree():
		return value
	var viewport_size := label.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return value
	return Vector2(
		clampf(value.x, 0.0, maxf(0.0, viewport_size.x - label.size.x)),
		clampf(value.y, 0.0, maxf(0.0, viewport_size.y - label.size.y))
	).round()

func _compute_pop_offset(
	style_profile: Resource,
	tier: int,
	damage_type: StringName,
	is_periodic: bool
) -> Vector2:
	var distance: float = style_profile.get_pop_distance(tier, damage_type)
	var horizontal_ratio: float = style_profile.get_horizontal_ratio(damage_type)
	if is_periodic:
		distance *= float(style_profile.periodic_distance_multiplier)
	return Vector2(
		roundf(randf_range(-horizontal_ratio, horizontal_ratio) * distance),
		-roundf(distance)
	)
