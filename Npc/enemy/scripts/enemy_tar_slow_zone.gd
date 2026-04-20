extends Area2D
class_name EnemyTarSlowZone

@export var duration: float = 4.0
@export var radius: float = 90.0
@export var player_slow_multiplier: float = 0.65
@export var enemy_slow_multiplier: float = 0.65
@export var enemy_refresh_duration: float = 0.25
@export var draw_zone: bool = true
@export var zone_fill_color: Color = Color(0.2, 0.16, 0.1, 0.28)
@export var zone_line_color: Color = Color(0.55, 0.42, 0.2, 0.95)
@export var zone_line_width: float = 2.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var life_timer: Timer = $LifeTimer

var _field_source_id: StringName
var _slowed_players: Dictionary = {}

func _ready() -> void:
	add_to_group("enemy_runtime_cleanup")
	_field_source_id = StringName("tar_zone_%d" % get_instance_id())
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius = maxf(radius, 1.0)
	life_timer.wait_time = maxf(duration, 0.1)
	life_timer.start()

func _physics_process(_delta: float) -> void:
	if draw_zone:
		queue_redraw()
	for area in get_overlapping_areas():
		if not (area is HurtBox):
			continue
		var target := _resolve_target(area as HurtBox)
		if target == null or not is_instance_valid(target):
			continue
		if target is BaseEnemy:
			var enemy := target as BaseEnemy
			enemy.apply_slow(clampf(enemy_slow_multiplier, 0.05, 1.0), enemy_refresh_duration)

func _on_area_entered(area: Area2D) -> void:
	if not (area is HurtBox):
		return
	var target := _resolve_target(area as HurtBox)
	if target == null or not is_instance_valid(target):
		return
	if target is Player:
		var player := target as Player
		player.apply_move_speed_mul(_field_source_id, clampf(player_slow_multiplier, 0.05, 1.0))
		_slowed_players[player.get_instance_id()] = player

func _on_area_exited(area: Area2D) -> void:
	if not (area is HurtBox):
		return
	var target := _resolve_target(area as HurtBox)
	if target == null or not is_instance_valid(target):
		return
	if target is Player:
		_remove_player_slow(target as Player)

func _on_life_timer_timeout() -> void:
	_cleanup_all_player_slow()
	queue_free()

func _exit_tree() -> void:
	_cleanup_all_player_slow()

func _resolve_target(hurt_box: HurtBox) -> Node:
	if hurt_box.has_method("get_damage_target"):
		return hurt_box.call("get_damage_target")
	return hurt_box.get_owner()

func _remove_player_slow(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.remove_move_speed_mul(_field_source_id)
	_slowed_players.erase(player.get_instance_id())

func _cleanup_all_player_slow() -> void:
	for player_variant in _slowed_players.values():
		var player := player_variant as Player
		if player and is_instance_valid(player):
			player.remove_move_speed_mul(_field_source_id)
	_slowed_players.clear()

func _draw() -> void:
	if not draw_zone:
		return
	draw_circle(Vector2.ZERO, maxf(radius, 1.0), zone_fill_color)
	draw_arc(
		Vector2.ZERO,
		maxf(radius, 1.0),
		0.0,
		TAU,
		56,
		zone_line_color,
		maxf(zone_line_width, 1.0),
		true
	)
