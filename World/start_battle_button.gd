extends Area2D
class_name StartBattleButton

signal activated

@export var hold_duration: float = 0.5
@export var radius: float = 34.0
@export var prompt_text: String = "Hold F to Start"
@export var debug_mode: bool = false
@export var debug_print_interval: float = 0.4

var _player_inside := false
var _hold_elapsed := 0.0
var _triggered := false
@onready var _prompt_label: Label = $PromptLabel
@onready var _shape: CollisionShape2D = $CollisionShape2D
var _debug_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	set_physics_process(true)
	if debug_mode:
		print("[StartBattleButton] ready name=%s parent=%s visible=%s process_mode=%s"
			% [name, str(get_parent()), str(visible), str(process_mode)])
	if _shape:
		var circle := _shape.shape as CircleShape2D
		if circle == null:
			circle = CircleShape2D.new()
			_shape.shape = circle
		circle.radius = radius
	if _prompt_label:
		_prompt_label.text = prompt_text
		_prompt_label.modulate = Color(0.95, 0.98, 1.0, 0.95)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_refresh_player_proximity()
	if debug_mode:
		_debug_elapsed += delta
		if _debug_elapsed >= maxf(0.1, debug_print_interval):
			_debug_elapsed = 0.0
			var is_pressed := Input.is_action_pressed("INTERACT")
			print("[StartBattleButton] inside=%s pressed=%s hold=%.2f/%.2f pos=%s player=%s"
				% [str(_player_inside), str(is_pressed), _hold_elapsed, hold_duration, str(global_position), str(PlayerData.player.global_position if PlayerData.player else Vector2.ZERO)])
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

func _refresh_player_proximity() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		_player_inside = false
		return
	var dist_sq := PlayerData.player.global_position.distance_squared_to(global_position)
	var radius_sq := radius * radius
	if dist_sq <= radius_sq:
		_player_inside = true
	else:
		if _player_inside:
			_player_inside = false
			_hold_elapsed = 0.0


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

func reset_state() -> void:
	_triggered = false
	_hold_elapsed = 0.0
	_player_inside = false
	_debug_elapsed = 0.0
	queue_redraw()
