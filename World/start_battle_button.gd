extends Area2D
class_name StartBattleButton

signal activated

@export var hold_duration: float = 0.5
@export var radius: float = 34.0
@export var prompt_text: String = "Hold F to Start"

var _player_inside := false
var _hold_elapsed := 0.0
var _triggered := false
var _prompt_label: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

	_prompt_label = Label.new()
	_prompt_label.text = prompt_text
	_prompt_label.position = Vector2(-68.0, -52.0)
	_prompt_label.modulate = Color(0.95, 0.98, 1.0, 0.95)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	if not _player_inside:
		if _hold_elapsed > 0.0:
			_hold_elapsed = 0.0
			queue_redraw()
		return
	if Input.is_action_pressed("INTERACT"):
		_hold_elapsed = minf(_hold_elapsed + delta, hold_duration)
		if _hold_elapsed >= hold_duration:
			_triggered = true
			activated.emit()
	else:
		if _hold_elapsed > 0.0:
			_hold_elapsed = 0.0
	queue_redraw()


func _draw() -> void:
	var ratio := _get_progress_ratio()
	var idle_color := Color(0.10, 0.18, 0.22, 0.80)
	var ring_color := Color(0.65, 0.84, 1.0, 0.95)
	var progress_color := Color(0.36, 0.92, 0.56, 1.0)
	draw_circle(Vector2.ZERO, radius, idle_color)
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 48, ring_color, 2.0)
	if ratio > 0.0:
		draw_arc(Vector2.ZERO, radius + 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, progress_color, 4.0)


func _get_progress_ratio() -> float:
	if hold_duration <= 0.0:
		return 1.0
	return clampf(_hold_elapsed / hold_duration, 0.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = false
		_hold_elapsed = 0.0
		queue_redraw()
