extends PanelContainer

const MAX_WIDTH := 440.0
const MIN_WIDTH := 240.0
const HORIZONTAL_RESERVED_SPACE := 720.0
const HEIGHT := 44.0
const TOP_OFFSET := 86.0

@onready var message_label: Label = %Message

var _generation := 0
var _tween: Tween


func set_message(text: String) -> void:
	message_label.text = text


func show_message(text: String, duration: float = 1.8) -> void:
	_generation += 1
	var generation := _generation
	_kill_tween()
	set_message(text)
	layout_in(get_viewport_rect().size)
	visible = not text.is_empty()
	if not visible:
		return
	modulate.a = 0.0
	position.y += 6.0
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	_tween.tween_property(self, "position:y", position.y - 6.0, 0.18)
	await get_tree().create_timer(maxf(duration, 0.1)).timeout
	if generation != _generation or not is_inside_tree():
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(_hide.bind(generation))


func layout_in(viewport_size: Vector2) -> void:
	var width := minf(MAX_WIDTH, maxf(MIN_WIDTH, viewport_size.x - HORIZONTAL_RESERVED_SPACE))
	position = Vector2(roundf((viewport_size.x - width) * 0.5), TOP_OFFSET)
	size = Vector2(width, HEIGHT)


func clear() -> void:
	_generation += 1
	_kill_tween()
	visible = false
	modulate.a = 1.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _hide(generation: int) -> void:
	if generation == _generation:
		visible = false
		modulate.a = 1.0
