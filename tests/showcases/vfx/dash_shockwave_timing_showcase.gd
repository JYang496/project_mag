extends Node2D

const LOOP_DELAY := 0.55
const ANIMATION_NAME := &"dash_shockwave"
const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_01_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_02_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_03_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_04_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_05_normalized.png"),
	preload("res://Player/Skills/assets/dash_shockwave/dash_shockwave_frame_06_normalized.png"),
]
const PHASE_LABELS := [
	"PRESSURE CORE",
	"RAPID STRETCH",
	"PEAK IMPACT",
	"BREAK APART",
	"DISSIPATE",
	"FADE OUT",
]

var _preview: AnimatedSprite2D
var _phase_label: Label
var _loop_enabled := true
var _loop_wait := 0.0


func _ready() -> void:
	_build_stage()
	_build_sprite_animation()
	_play_preview()


func _process(delta: float) -> void:
	if _preview == null:
		return
	var frame_index := clampi(_preview.frame, 0, PHASE_LABELS.size() - 1)
	_phase_label.text = "PHASE  //  %s" % PHASE_LABELS[frame_index]
	if not _loop_enabled or _preview.is_playing():
		return
	_loop_wait += delta
	if _loop_wait >= LOOP_DELAY:
		_play_preview()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_play_preview()
	elif event.keycode == KEY_L:
		_loop_enabled = not _loop_enabled


func _build_sprite_animation() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop(ANIMATION_NAME, false)
	frames.set_animation_speed(ANIMATION_NAME, 8.4)
	for texture in FRAME_TEXTURES:
		frames.add_frame(ANIMATION_NAME, texture)

	_preview = AnimatedSprite2D.new()
	_preview.sprite_frames = frames
	_preview.animation = ANIMATION_NAME
	_preview.position = Vector2(640, 370)
	_preview.scale = Vector2(3.2, 3.2)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_preview)


func _play_preview() -> void:
	_loop_wait = 0.0
	_preview.stop()
	_preview.frame = 0
	_preview.play(ANIMATION_NAME)


func _build_stage() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280, 720)
	background.color = Color("07111f")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -100
	add_child(background)

	for x in range(0, 1281, 32):
		var line := ColorRect.new()
		line.position = Vector2(x, 0)
		line.size = Vector2(1, 720)
		line.color = Color(0.12, 0.28, 0.42, 0.12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = -90
		add_child(line)
	for y in range(0, 721, 32):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(1280, 1)
		line.color = Color(0.12, 0.28, 0.42, 0.12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = -90
		add_child(line)

	var title := _make_label("DASH SHOCKWAVE // GENERATED FRAME SHOWCASE", Vector2(32, 24), Vector2(1216, 36), 22, Color("8eefff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := _make_label("IMAGE-GENERATED FRAMES  //  128 PX SOURCE  //  3.2× NEAREST PREVIEW", Vector2(32, 64), Vector2(1216, 28), 13, Color(0.65, 0.82, 0.94, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_phase_label = _make_label("PHASE", Vector2(32, 116), Vector2(1216, 28), 14, Color("65cfff"))
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_phase_label)

	var baseline := ColorRect.new()
	baseline.position = Vector2(300, 369)
	baseline.size = Vector2(680, 2)
	baseline.color = Color(0.32, 0.72, 0.92, 0.16)
	baseline.z_index = -10
	add_child(baseline)

	var help := _make_label("SPACE  REPLAY     L  TOGGLE LOOP", Vector2(32, 650), Vector2(1216, 28), 13, Color(0.62, 0.78, 0.9, 0.85))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help)


func _make_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	return label
