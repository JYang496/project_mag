extends Area2D

signal presence_changed(beacon_id: int, player_inside: bool, enemy_count: int)

@export var beacon_id := 0
var _player_inside := false
var _enemies: Dictionary = {}
var _progress := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	$ProgressGround.radius = lerpf(10.0, 66.0, _progress)

func _on_body_entered(body: Node2D) -> void:
	if body == PlayerData.player:
		_player_inside = true
	elif body.is_in_group("enemies"):
		_enemies[body.get_instance_id()] = body
	_emit_presence()

func _on_body_exited(body: Node2D) -> void:
	if body == PlayerData.player:
		_player_inside = false
	else:
		_enemies.erase(body.get_instance_id())
	_emit_presence()

func _emit_presence() -> void:
	for id in _enemies.keys():
		if not is_instance_valid(_enemies[id]):
			_enemies.erase(id)
	presence_changed.emit(beacon_id, _player_inside, _enemies.size())
