extends Label

@export var pop_distance_min: float = 36.0
@export var pop_distance_max: float = 72.0
@export var pop_duration: float = 0.18
@export var fade_duration: float = 0.12
@export var life_time: float = 0.32
@export var min_scale_value: float = 0.9
@export var max_scale_value: float = 1.8
@export var damage_scale_cap: int = 60

var _damage_value: int = 0

func _ready() -> void:
	var start_scale: float = _compute_target_scale(_damage_value)
	var target_scale: Vector2 = Vector2(start_scale, start_scale)
	var pop_offset: Vector2 = _compute_pop_offset()
	var target_position: Vector2 = position + pop_offset

	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, pop_duration).from(target_scale * 0.25)
	tween.tween_property(self, "position", target_position, pop_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(maxf(0.0, life_time - fade_duration))
	tween.tween_callback(self.queue_free).set_delay(life_time)

func setNumber(number: int) -> void:
	_damage_value = max(0, number)
	text = str(_damage_value)

func setColor(color: Color) -> void:
	set("theme_override_colors/font_color", color)

func _compute_pop_offset() -> Vector2:
	var angle: float = deg_to_rad(randf_range(-135.0, -45.0))
	var distance: float = randf_range(pop_distance_min, pop_distance_max)
	return Vector2(cos(angle), sin(angle)) * distance

func _compute_target_scale(damage: int) -> float:
	var capped_damage: int = min(max(0, damage), max(1, damage_scale_cap))
	var t: float = float(capped_damage) / float(max(1, damage_scale_cap))
	return lerpf(min_scale_value, max_scale_value, t)
