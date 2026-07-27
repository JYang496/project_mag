extends Control

const DEFAULT_STYLE := preload("res://UI/labels/damage_label_style_profile.tres")
const DamageFeedbackEventType := preload("res://Combat/damage/damage_feedback_event.gd")
const DigitRendererType := preload("res://UI/labels/damage_digit_renderer.gd")
const HitLabelMotionType := preload("res://UI/labels/hit_label_motion.gd")
const HitLabelCrowdingType := preload("res://UI/labels/hit_label_crowding.gd")

@export var style_profile: DamageLabelStyleProfile = DEFAULT_STYLE
@export var fade_duration: float = 0.12

var _damage_value: int = 0
var _damage_type: StringName = Attack.TYPE_PHYSICAL
var _target_max_hp: int = 0
var _target_instance_id: int = 0
var _feedback_batch_id: int = 0
var _is_critical: bool = false
var _is_periodic: bool = false
var _is_killing_blow: bool = false
var _display_text := "0"
var _pixel_scale: int = 1
var _outline_pixels: int = 1
var _font_color := Color.WHITE
var _outline_color := Color(0.03, 0.04, 0.06, 0.96)
var _digit_renderer = DigitRendererType.new()
var _motion = HitLabelMotionType.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_visual_state()
	position = (position - size * 0.5).round()
	position = _motion.clamp_to_viewport(self, position)
	HitLabelCrowdingType.resolve(self, _motion)
	add_to_group(HitLabelCrowdingType.GROUP)
	_restart_animation()

func configure(feedback: Variant) -> void:
	var event = _coerce_feedback_event(feedback)
	_damage_value = event.final_damage
	_damage_type = event.damage_type
	_target_max_hp = event.target_max_hp
	_target_instance_id = event.target_instance_id if event.target_instance_id > 0 else _target_instance_id
	_is_critical = event.is_critical
	_is_periodic = event.is_periodic
	_is_killing_blow = event.is_killing_blow
	_feedback_batch_id = event.feedback_batch_id
	_apply_visual_state()

func merge_feedback(feedback: Variant) -> void:
	var current = DamageFeedbackEventType.new(_damage_value, _damage_type)
	current.target_max_hp = _target_max_hp
	current.target_instance_id = _target_instance_id
	current.feedback_batch_id = _feedback_batch_id
	current.is_critical = _is_critical
	current.is_periodic = _is_periodic
	current.is_killing_blow = _is_killing_blow
	current.merge(_coerce_feedback_event(feedback))
	configure(current)
	if is_inside_tree():
		_restart_animation()

# Compatibility entry points retained for existing callers and projection tests.
func setNumber(number: int) -> void:
	configure({"final_damage": number, "damage_type": _damage_type})

func setColor(color: Color) -> void:
	_font_color = color
	queue_redraw()

func merge_damage(number: int, color: Color) -> void:
	_damage_value += max(0, number)
	_apply_visual_state()
	_font_color = color
	queue_redraw()
	if is_inside_tree():
		_restart_animation()

func set_target_instance_id(value: int) -> void:
	_target_instance_id = value

func get_target_instance_id() -> int:
	return _target_instance_id

func get_damage_value() -> int:
	return _damage_value

func get_damage_type() -> StringName:
	return _damage_type

func get_pixel_scale() -> int:
	return _pixel_scale

func get_display_text() -> String:
	return _display_text

func get_font_color() -> Color:
	return _font_color

func get_outline_color() -> Color:
	return _outline_color

func is_critical_hit() -> bool:
	return _is_critical

func is_periodic_hit() -> bool:
	return _is_periodic

func get_feedback_batch_id() -> int:
	return _feedback_batch_id

func _draw() -> void:
	_digit_renderer.render(
		self,
		_display_text,
		_pixel_scale,
		_outline_pixels,
		_font_color,
		_outline_color,
		style_profile.critical_color
	)

func _apply_visual_state() -> void:
	if style_profile == null:
		style_profile = DEFAULT_STYLE
	var tier := style_profile.resolve_tier(_damage_value, _target_max_hp)
	_pixel_scale = style_profile.get_pixel_scale(tier, _is_critical or _is_killing_blow)
	_outline_pixels = style_profile.get_outline_pixels(tier, _is_critical or _is_killing_blow)
	_font_color = style_profile.get_color(_damage_type, _is_critical or _is_killing_blow)
	_outline_color = (
		style_profile.periodic_outline_color
		if _is_periodic
		else style_profile.outline_color
	)
	_display_text = str(_damage_value) + ("!" if _is_critical else "")
	_apply_layout()
	queue_redraw()

func _apply_layout() -> void:
	size = _digit_renderer.measure(_display_text, _pixel_scale, _outline_pixels)
	pivot_offset = size * 0.5

func _restart_animation() -> void:
	var tier := style_profile.resolve_tier(_damage_value, _target_max_hp)
	_motion.restart(
		self,
		style_profile,
		tier,
		_damage_type,
		_is_periodic,
		_is_critical or _is_killing_blow,
		fade_duration
	)

func _coerce_feedback_event(feedback: Variant):
	if is_instance_of(feedback, DamageFeedbackEventType):
		return feedback
	if feedback is Dictionary:
		return DamageFeedbackEventType.new().apply_dictionary(feedback as Dictionary)
	return DamageFeedbackEventType.new()
