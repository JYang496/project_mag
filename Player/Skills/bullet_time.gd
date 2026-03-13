extends Skills

@export var time_scale: float = 0.5
@export var speed_bonus_multiplier: float = 3.0
@export var default_cooldown: float = 5.0

@onready var timer: Timer = $Timer

var saved_scale: float = 1.0
var saved_speed: float = 0.0
var _active := false

func on_skill_ready() -> void:
	if cooldown <= 0.0:
		cooldown = default_cooldown

func can_activate() -> bool:
	return not _active

func activate_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_active = true
	saved_scale = Engine.time_scale
	Engine.time_scale = time_scale
	saved_speed = PlayerData.player_speed * speed_bonus_multiplier
	PlayerData.player_bonus_speed += saved_speed
	timer.start()

func _on_timer_timeout() -> void:
	if not _active:
		return
	Engine.time_scale = saved_scale
	PlayerData.player_bonus_speed -= saved_speed
	saved_speed = 0.0
	_active = false

func _exit_tree() -> void:
	if not _active:
		return
	Engine.time_scale = saved_scale
	PlayerData.player_bonus_speed -= saved_speed
