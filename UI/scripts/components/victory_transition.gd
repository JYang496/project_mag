extends Control
class_name VictoryTransition

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
var _subtitle: Label
var _playing := false
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500
	_build_view()
	visible = false
	LocalizationManager.language_changed.connect(_on_language_changed)

func _build_view() -> void:
	_banner = ColorRect.new()
	_banner.color = Color(0.02, 0.025, 0.035, 0.78)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-640.0, -BANNER_HEIGHT * 0.5)
	_banner.size = Vector2(1280.0, BANNER_HEIGHT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	for y in [0.0, BANNER_HEIGHT - 2.0]:
		var accent := ColorRect.new()
		accent.color = Color(0.35, 0.82, 1.0, 0.75)
		accent.position = Vector2(0.0, y)
		accent.size = Vector2(1280.0, 2.0)
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_child(accent)

	_title_group = VBoxContainer.new()
	_title_group.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_group)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	_title.add_theme_color_override("font_shadow_color", Color(0.1, 0.55, 0.8, 0.8))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title_group.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Color(0.55, 0.82, 0.95))
	_title_group.add_child(_subtitle)
	_refresh_text()

func play() -> void:
	if _playing:
		await finished
		return
	_playing = true
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
	_tween.tween_property(_banner, "modulate:a", 1.0, FADE_IN_DURATION)
	_tween.parallel().tween_property(_title_group, "position", overshoot, SLIDE_IN_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.08)
	_tween.parallel().tween_property(_title_group, "scale", Vector2.ONE, SLIDE_IN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	_tween.tween_property(_title_group, "position", centered, REBOUND_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_DURATION)
	_tween.tween_property(_title_group, "position", centered - Vector2(10.0, 0.0), WINDUP_DURATION)
	_tween.tween_property(_title_group, "position", exit_end, SLIDE_OUT_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_banner, "modulate:a", 0.0, FADE_OUT_DURATION).set_delay(0.05)
	await _tween.finished
	_tween = null
	visible = false
	_playing = false
	finished.emit()

func is_playing() -> bool:
	return _playing

func _refresh_text() -> void:
	var is_chinese := LocalizationManager.get_locale() == "zh_CN"
	_title.text = LocalizationManager.tr_key("ui.battle_victory.title", "战斗胜利" if is_chinese else "VICTORY")
	_subtitle.text = LocalizationManager.tr_key("ui.battle_victory.subtitle", "战斗完成" if is_chinese else "BATTLE COMPLETE")

func _on_language_changed(_locale: String) -> void:
	_refresh_text()
