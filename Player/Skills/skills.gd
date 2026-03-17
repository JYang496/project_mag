extends Node2D
class_name Skills

@export var cooldown: float = 0.0

var _player: Player
var _on_cooldown := false

func _ready() -> void:
	call_deferred("_bind_player_and_initialize")

func _bind_player_and_initialize() -> void:
	_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		await get_tree().process_frame
		_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		push_warning("%s failed to initialize: player not found." % name)
		return
	var callable_ref := Callable(self, "_on_player_active_skill_requested")
	if not _player.active_skill.is_connected(callable_ref):
		_player.active_skill.connect(callable_ref)
	on_skill_ready()

func _resolve_player() -> Player:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		return PlayerData.player
	var current: Node = get_parent()
	while current:
		if current is Player:
			return current as Player
		current = current.get_parent()
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and player_node is Player:
		return player_node as Player
	return null

func _on_player_active_skill_requested() -> void:
	if _on_cooldown:
		return
	if not can_activate():
		return
	activate_skill()
	if cooldown > 0.0:
		_start_cooldown()

func _start_cooldown() -> void:
	_on_cooldown = true
	await get_tree().create_timer(cooldown).timeout
	_on_cooldown = false

func on_skill_ready() -> void:
	pass

func can_activate() -> bool:
	return true

func activate_skill() -> void:
	pass
