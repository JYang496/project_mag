extends Label
class_name GoldHudDisplay

const COIN_TEXTURE := preload("res://asset/images/loot/credit_coin_01.png")

const DISPLAY_SIZE := Vector2(112.0, 38.0)
const ICON_SIZE := Vector2(30.0, 30.0)
const ICON_POSITION := Vector2(2.0, 4.0)
const VALUE_POSITION := Vector2(38.0, 2.0)
const VALUE_SIZE := Vector2(72.0, 34.0)
const GAIN_COLOR := Color(1.0, 0.84, 0.25, 1.0)
const SPEND_COLOR := Color(1.0, 0.42, 0.22, 1.0)

var displayed_gold: float = 0.0:
	set(value):
		displayed_gold = value
		_update_value_label()

var _target_gold := 0
var _initialized := false
var _icon: TextureRect
var _value_label: Label
var _value_tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	custom_minimum_size = DISPLAY_SIZE
	size = DISPLAY_SIZE
	pivot_offset = DISPLAY_SIZE * 0.5
	_ensure_children()
	_update_value_label()

func set_gold_value(value: int, animate: bool = true) -> void:
	_ensure_children()
	var next_gold := maxi(value, 0)
	if not _initialized:
		_initialized = true
		_target_gold = next_gold
		displayed_gold = float(next_gold)
		tooltip_text = _format_tooltip(next_gold)
		return

	if next_gold == _target_gold:
		return

	var delta := next_gold - _target_gold
	_target_gold = next_gold
	tooltip_text = _format_tooltip(next_gold)

	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	if animate:
		_value_tween = create_tween()
		_value_tween.tween_property(self, "displayed_gold", float(next_gold), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		displayed_gold = float(next_gold)

	_show_delta(delta)
	if delta > 0:
		_play_gain_pulse()

func get_target_gold() -> int:
	return _target_gold

func _ensure_children() -> void:
	if _icon == null or not is_instance_valid(_icon):
		_icon = TextureRect.new()
		_icon.name = "CoinIcon"
		_icon.texture = COIN_TEXTURE
		_icon.position = ICON_POSITION
		_icon.size = ICON_SIZE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)

	if _value_label == null or not is_instance_valid(_value_label):
		_value_label = Label.new()
		_value_label.name = "Value"
		_value_label.position = VALUE_POSITION
		_value_label.size = VALUE_SIZE
		_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_value_label.add_theme_font_size_override("font_size", 21)
		_value_label.add_theme_color_override("font_color", Color(0.965, 0.91, 0.69, 1.0))
		_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_value_label.add_theme_constant_override("outline_size", 2)
		_value_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.52))
		_value_label.add_theme_constant_override("shadow_offset_x", 1)
		_value_label.add_theme_constant_override("shadow_offset_y", 2)
		add_child(_value_label)

func _update_value_label() -> void:
	if _value_label == null or not is_instance_valid(_value_label):
		return
	_value_label.text = str(maxi(0, int(round(displayed_gold))))

func _show_delta(delta: int) -> void:
	if delta == 0:
		return
	var delta_label := Label.new()
	delta_label.text = "+%d" % delta if delta > 0 else "%d" % delta
	delta_label.position = Vector2(DISPLAY_SIZE.x - 8.0, 4.0)
	delta_label.size = Vector2(64.0, 24.0)
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	delta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delta_label.add_theme_font_size_override("font_size", 16)
	delta_label.add_theme_color_override("font_color", GAIN_COLOR if delta > 0 else SPEND_COLOR)
	delta_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.76))
	delta_label.add_theme_constant_override("shadow_offset_x", 1)
	delta_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(delta_label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(delta_label, "position", delta_label.position + Vector2(0.0, -22.0), 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(delta_label, "modulate:a", 0.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(delta_label.queue_free)

func _play_gain_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _format_tooltip(value: int) -> String:
	return LocalizationManager.tr_format("ui.hud.gold", {"value": value}, "Gold: %s" % str(value))
