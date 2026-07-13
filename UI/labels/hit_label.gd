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
var _target_instance_id: int = 0
var _tween: Tween

const CROWD_GROUP := &"active_hit_labels"
const CROWD_RADIUS: float = 42.0
const CROWD_VERTICAL_STEP: float = 22.0

func _ready() -> void:
	_resolve_crowding()
	add_to_group(CROWD_GROUP)
	_restart_animation()

func _restart_animation() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	var start_scale: float = _compute_target_scale(_damage_value)
	var target_scale: Vector2 = Vector2(start_scale, start_scale)
	var pop_offset: Vector2 = _compute_pop_offset()
	var target_position: Vector2 = position + pop_offset

	modulate.a = 1.0
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, pop_duration).from(target_scale * 0.7)
	_tween.tween_property(self, "position", target_position, pop_duration)
	_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(maxf(0.0, life_time - fade_duration))
	_tween.tween_callback(self.queue_free).set_delay(life_time)

func setNumber(number: int) -> void:
	_damage_value = max(0, number)
	text = str(_damage_value)

func set_target_instance_id(value: int) -> void:
	_target_instance_id = value

func get_target_instance_id() -> int:
	return _target_instance_id

func get_damage_value() -> int:
	return _damage_value

func merge_damage(number: int, color: Color) -> void:
	_damage_value += max(0, number)
	text = str(_damage_value)
	setColor(color)
	_restart_animation()

func setColor(color: Color) -> void:
	set("theme_override_colors/font_color", color)

func _compute_pop_offset() -> Vector2:
	var distance: float = randf_range(pop_distance_min, pop_distance_max)
	# World UI always rises toward the top of the screen. Horizontal variance keeps
	# simultaneous labels readable without allowing sideways/downward pops.
	return Vector2(randf_range(-0.28, 0.28) * distance, -distance)

func _compute_target_scale(damage: int) -> float:
	var capped_damage: int = min(max(0, damage), max(1, damage_scale_cap))
	var t: float = float(capped_damage) / float(max(1, damage_scale_cap))
	return lerpf(min_scale_value, max_scale_value, t)

func _resolve_crowding() -> void:
	if not is_inside_tree():
		return
	var occupied_level := 0
	for item in get_tree().get_nodes_in_group(CROWD_GROUP):
		var label := item as Control
		if label == null or not is_instance_valid(label):
			continue
		if label.position.distance_to(position) <= CROWD_RADIUS:
			occupied_level += 1
	position.y -= float(mini(occupied_level, 4)) * CROWD_VERTICAL_STEP
