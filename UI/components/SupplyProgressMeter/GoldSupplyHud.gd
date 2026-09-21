extends Button

const METER := preload("res://UI/components/SupplyProgressMeter/SupplyProgressMeter.gd")
const ICON := preload("res://UI/themes/modern/supply_crate_icon.png")
const FOOTPRINT := Vector2(250, 80)

var title_label: Label
var action_label: Label
var progress_label: Label
var progress_bar: Control
var crate_icon: TextureRect
var _action_panel: StyleBoxFlat
var _action_background: Panel
var _ready_to_claim := false
var _clock := 0.0
var _flash := 0.0
var _icon_tween: Tween
var _audio: AudioStreamPlayer
var _feedback: Panel
var _feedback_label: Label
var _feedback_generation := 0
var _ready_badge: ColorRect

func _init() -> void:
	name = "GoldSupplyHud"
	custom_minimum_size = FOOTPRINT
	size = FOOTPRINT
	focus_mode = Control.FOCUS_NONE
	flat = true
	var empty_style := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, empty_style)
	crate_icon = TextureRect.new()
	crate_icon.texture = ICON
	crate_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crate_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crate_icon.position = Vector2(12, 4)
	crate_icon.size = Vector2(28, 28)
	crate_icon.pivot_offset = Vector2(14, 14)
	crate_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crate_icon)
	_ready_badge = ColorRect.new()
	_ready_badge.position = Vector2(34, 4)
	_ready_badge.size = Vector2(8, 8)
	_ready_badge.color = Color("ffe36a")
	_ready_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ready_badge.visible = false
	add_child(_ready_badge)
	title_label = _label(Vector2(48, 6), Vector2(190, 22), 16)
	_action_background = Panel.new()
	_action_background.position = Vector2(12, 30)
	_action_background.size = Vector2(226, 24)
	_action_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel = StyleBoxFlat.new()
	_action_panel.bg_color = Color("253338")
	_action_panel.set_corner_radius_all(3)
	_action_panel.corner_detail = 1
	_action_background.add_theme_stylebox_override("panel", _action_panel)
	add_child(_action_background)
	action_label = _label(Vector2(12, 30), Vector2(226, 24), 16)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label = _label(Vector2(12, 54), Vector2(226, 18), 12)
	progress_label.add_theme_color_override("font_color", Color("bdc9c6"))
	progress_bar = METER.new()
	progress_bar.position = Vector2(12, 72)
	progress_bar.size = Vector2(226, 6)
	add_child(progress_bar)
	_feedback = Panel.new()
	_feedback.position = Vector2(-60, -88)
	_feedback.size = Vector2(300, 80)
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.visible = false
	var feedback_panel := StyleBoxFlat.new()
	feedback_panel.bg_color = Color("101e22")
	feedback_panel.border_color = Color("65562e")
	feedback_panel.set_border_width_all(1)
	feedback_panel.set_corner_radius_all(4)
	feedback_panel.corner_detail = 1
	_feedback.add_theme_stylebox_override("panel", feedback_panel)
	add_child(_feedback)
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(12, 8)
	_feedback_label.size = Vector2(276, 64)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color("fff0a8"))
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.add_child(_feedback_label)

func show_feedback(message: String, duration: float) -> void:
	_feedback_generation += 1
	var generation := _feedback_generation
	_feedback_label.text = message
	_feedback.visible = true
	await get_tree().create_timer(duration).timeout
	if generation == _feedback_generation and is_inside_tree():
		_feedback.visible = false

func clear_feedback() -> void:
	_feedback_generation += 1
	_feedback.visible = false

func set_ready_count(count: int) -> void:
	_ready_badge.visible = count > 0

func _label(origin: Vector2, footprint: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = origin
	label.size = footprint
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e7eee9"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func set_claim_available(available: bool) -> void:
	_ready_to_claim = available
	action_label.add_theme_color_override("font_color", Color("fff0a8") if available else Color("bdc9c6"))
	crate_icon.modulate = Color.WHITE if available else Color("a4b6b0")
	set_process(available or _flash > 0.0)
	if not available:
		_action_panel.bg_color = Color("253338")

func announce_ready(play_sound: bool = true) -> void:
	_flash = 1.0
	set_process(true)
	if _icon_tween != null and _icon_tween.is_valid():
		_icon_tween.kill()
	_icon_tween = create_tween()
	_icon_tween.tween_property(crate_icon, "scale", Vector2(1.08, 1.08), 0.12)
	_icon_tween.tween_property(crate_icon, "scale", Vector2.ONE, 0.22)
	if play_sound:
		_play_tone()

func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	var strength := (0.5 + 0.5 * sin(_clock * TAU / 2.8)) if _ready_to_claim else 0.0
	_action_panel.bg_color = Color("253338").lerp(Color("665226"), strength * 0.65)
	if not _ready_to_claim and _flash <= 0.0:
		set_process(false)

func _play_tone() -> void:
	if _audio == null:
		_audio = AudioStreamPlayer.new()
		_audio.bus = &"SFX"
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = 22050
		stream.buffer_length = 0.2
		_audio.stream = stream
		add_child(_audio)
	_audio.play()
	var playback := _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	for index in 3307:
		var time := float(index) / 22050.0
		var envelope := sin(PI * float(index) / 3307.0)
		var sample := sin(TAU * (660.0 if index < 1654 else 880.0) * time) * envelope * 0.12
		playback.push_frame(Vector2(sample, sample))
	get_tree().create_timer(0.18).timeout.connect(_audio.stop)

func _exit_tree() -> void:
	if _icon_tween != null and _icon_tween.is_valid():
		_icon_tween.kill()
