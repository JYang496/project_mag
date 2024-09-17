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
var gates_state := "off"
var doors_state := "on"
var open_distance := 64

signal tp_to_battle_zone()

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if doors_state == "on":
		door_left.position = door_left.position.move_toward(Vector2(door_left_position.x - open_distance,door_left_position.y),delta*door_speed)
		door_right.position = door_right.position.move_toward(Vector2(door_right_position.x + open_distance,door_right_position.y),delta*door_speed)
	else:
		door_left.position = door_left.position.move_toward(Vector2(door_left_position.x,door_left_position.y),delta*door_speed)
		door_right.position = door_right.position.move_toward(Vector2(door_right_position.x,door_right_position.y),delta*door_speed)
	
	if gates_state == "on":
		gate_left.position = gate_left.position.move_toward(Vector2(gate_left_position.x - open_distance,gate_left_position.y),delta*door_speed)
		gate_right.position = gate_right.position.move_toward(Vector2(gate_right_position.x + open_distance,gate_right_position.y),delta*door_speed)
	else:
		gate_left.position = gate_left.position.move_toward(Vector2(gate_left_position.x,gate_left_position.y),delta*door_speed)
		gate_right.position = gate_right.position.move_toward(Vector2(gate_right_position.x,gate_right_position.y),delta*door_speed)



func _on_dectect_area_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	# Body is player
	# Doors state change, sprite move
	doors_state = "off"
	# Gate state change, layer move
	gates_state = "on"
	# Trigger player not move by sending signal to player_teleport
	emit_signal("tp_to_battle_zone")
