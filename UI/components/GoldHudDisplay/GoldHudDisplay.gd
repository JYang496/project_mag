extends Control

const COIN_TEXTURE := preload("res://asset/images/loot/credit_coin_01.png")

const DISPLAY_SIZE := Vector2(112.0, 38.0)
const ICON_SIZE := Vector2(30.0, 30.0)
const ICON_POSITION := Vector2(2.0, 4.0)
const VALUE_POSITION := Vector2(38.0, 2.0)
const VALUE_SIZE := Vector2(72.0, 34.0)
const GAIN_COLOR := Color(1.0, 0.84, 0.25, 1.0)
const SPEND_COLOR := Color(1.0, 0.42, 0.22, 1.0)
const STEADY_ALPHA := 0.72

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
	pivot_offset = DISPLAY_SIZE * 0.5
	modulate.a = STEADY_ALPHA
	_icon = %CoinIcon
	_value_label = %Value
	_update_value_label()

func set_gold_value(value: int, animate: bool = true) -> void:
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

func _update_value_label() -> void:
	if _value_label == null or not is_instance_valid(_value_label):
		return
	_value_label.text = str(maxi(0, int(round(displayed_gold))))

func _show_delta(delta: int) -> void:
	if delta == 0:
		return
	var delta_label := preload("res://UI/components/GoldDeltaPopup/GoldDeltaPopup.tscn").instantiate() as Control
	add_child(delta_label)
	delta_label.call("show_delta", delta)

func _play_gain_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector2.ONE
	modulate.a = 1.0
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(true)
	_pulse_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "modulate:a", STEADY_ALPHA, 0.24).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pulse_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _format_tooltip(value: int) -> String:
	return LocalizationManager.tr_format("ui.hud.gold", {"value": value}, "Gold: %s" % str(value))
