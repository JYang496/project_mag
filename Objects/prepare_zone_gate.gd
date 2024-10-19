extends Node2D

@onready var gate_right = $GateRight
@onready var gate_left = $GateLeft
@onready var door_right = $DoorRight
@onready var door_left = $DoorLeft
@onready var detect_area = $DectectArea

@onready var gate_left_position = gate_left.position
@onready var gate_right_position = gate_right.position
@onready var door_left_position = door_left.position
@onready var door_right_position = door_right.position

var door_speed := 30.0
var gates_state = "close"
var doors_state = "close"
var open_distance := 64

signal tp_to_dest1()

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if doors_state == "open":
		door_left.position = door_left.position.move_toward(Vector2(door_left_position.x - open_distance,door_left_position.y),delta*door_speed)
		door_right.position = door_right.position.move_toward(Vector2(door_right_position.x + open_distance,door_right_position.y),delta*door_speed)
	else:
		door_left.position = door_left.position.move_toward(Vector2(door_left_position.x,door_left_position.y),delta*door_speed)
		door_right.position = door_right.position.move_toward(Vector2(door_right_position.x,door_right_position.y),delta*door_speed)
	
	if gates_state == "open":
		gate_left.position = gate_left.position.move_toward(Vector2(gate_left_position.x - open_distance,gate_left_position.y),delta*door_speed)
		gate_right.position = gate_right.position.move_toward(Vector2(gate_right_position.x + open_distance,gate_right_position.y),delta*door_speed)
	else:
		gate_left.position = gate_left.position.move_toward(Vector2(gate_left_position.x,gate_left_position.y),delta*door_speed)
		gate_right.position = gate_right.position.move_toward(Vector2(gate_right_position.x,gate_right_position.y),delta*door_speed)



func _on_dectect_area_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	# Body is player
	if PhaseManager.current_state() == PhaseManager.BONUS:
		doors_state = "open"
	if PhaseManager.current_state() == PhaseManager.PREPARE:
		emit_signal("tp_to_dest1")


func _on_prepare_dectect_area_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	if PhaseManager.current_state() == PhaseManager.BONUS:
		doors_state = "close"
	if PhaseManager.current_state() == PhaseManager.PREPARE:
		doors_state = "open"
	pass # Replace with function body.
