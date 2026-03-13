extends Node2D
class_name Skills

@export var cooldown: float = 0.0

var _player: Player
var _on_cooldown := false

func _ready() -> void:
	_player = PlayerData.player
	if _player == null or not is_instance_valid(_player):
		push_warning("%s failed to initialize: player not found." % name)
		return
	var callable_ref := Callable(self, "_on_player_active_skill_requested")
	if not _player.active_skill.is_connected(callable_ref):
		_player.active_skill.connect(callable_ref)
	on_skill_ready()

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

