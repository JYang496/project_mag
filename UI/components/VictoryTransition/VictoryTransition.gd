extends Control

signal finished

const BANNER_HEIGHT := 168.0
const FADE_IN_DURATION := 0.15
const SLIDE_IN_DURATION := 0.22
const REBOUND_DURATION := 0.08
const HOLD_DURATION := 0.75
const WINDUP_DURATION := 0.05
const SLIDE_OUT_DURATION := 0.25
const FADE_OUT_DURATION := 0.22

var _banner: ColorRect
var _title_group: VBoxContainer
var _title: Label
var _playing := false
var _tween: Tween
var _presentation_mode: StringName = &"quick"

func _ready() -> void:
	_banner = %Banner
	_title_group = %TitleGroup
	_title = %Title
	LocalizationManager.language_changed.connect(_on_language_changed)
	_refresh_text()

func play(presentation_mode: StringName = &"quick", _chapter: Resource = null) -> void:
	if _playing:
		await finished
		return
	_playing = true
	_presentation_mode = presentation_mode
	visible = true
	_refresh_text()
	await get_tree().process_frame
	var viewport_size := get_viewport_rect().size
	_banner.position = Vector2(0.0, (viewport_size.y - BANNER_HEIGHT) * 0.5)
	_banner.size.x = viewport_size.x
	for child in _banner.get_children():
		if child is ColorRect:
			child.size.x = viewport_size.x
	_title_group.reset_size()
	var centered := Vector2(
		(viewport_size.x - _title_group.size.x) * 0.5,
		(viewport_size.y - _title_group.size.y) * 0.5
	)
	var enter_start := Vector2(-_title_group.size.x - 60.0, centered.y)
	var overshoot := centered + Vector2(28.0, 0.0)
	var exit_end := Vector2(viewport_size.x + 60.0, centered.y)
	_banner.modulate.a = 0.0
	_title_group.position = enter_start
	_title_group.scale = Vector2(1.06, 1.06)
	_title_group.modulate.a = 1.0
	_title_group.pivot_offset = _title_group.size * 0.5

	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)
	var timing := animation_timing_for(_presentation_mode)
	var fade_in := float(timing.fade_in)
	var slide_in := float(timing.slide_in)
	var hold := float(timing.hold)
	var slide_out := float(timing.slide_out)
	var fade_out := float(timing.fade_out)
	_tween.tween_property(_banner, "modulate:a", 1.0, fade_in)
	_tween.parallel().tween_property(_title_group, "position", overshoot, slide_in).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(float(timing.enter_delay))
	_tween.parallel().tween_property(_title_group, "scale", Vector2.ONE, slide_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(float(timing.enter_delay))
	_tween.tween_property(_title_group, "position", centered, float(timing.rebound)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(_title_group, "position", centered - Vector2(10.0, 0.0), float(timing.windup))
	_tween.tween_property(_title_group, "position", exit_end, slide_out).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_banner, "modulate:a", 0.0, fade_out).set_delay(float(timing.exit_fade_delay))
	await _tween.finished
	_tween = null
	visible = false
	_playing = false
	finished.emit()

func is_playing() -> bool:
	return _playing

static func animation_timing_for(_presentation_mode: StringName) -> Dictionary:
	return {
		"fade_in": FADE_IN_DURATION,
		"slide_in": SLIDE_IN_DURATION,
		"enter_delay": 0.08,
		"rebound": REBOUND_DURATION,
		"hold": HOLD_DURATION,
		"windup": WINDUP_DURATION,
		"slide_out": SLIDE_OUT_DURATION,
		"fade_out": FADE_OUT_DURATION,
		"exit_fade_delay": 0.05,
	}

func _refresh_text() -> void:
	var is_chinese := LocalizationManager.get_locale() == "zh_CN"
	_title.text = LocalizationManager.tr_key("ui.battle_victory.complete", "协议已完成" if is_chinese else "PROTOCOL COMPLETE")

func _on_language_changed(_locale: String) -> void:
	_refresh_text()
