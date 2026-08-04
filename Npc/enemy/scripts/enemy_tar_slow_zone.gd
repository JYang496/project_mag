extends Area2D
class_name EnemyTarSlowZone

const TAR_SLOW_ZONE_TEXTURE: Texture2D = preload("res://asset/images/effects/slow_zone/tar_slow_zone_amber.png")

@export var duration: float = 4.0
@export var radius: float = 90.0
@export var player_slow_multiplier: float = 0.65
@export var enemy_slow_multiplier: float = 0.65
@export var enemy_refresh_duration: float = 0.25
@export var draw_zone: bool = true
@export var zone_fill_color: Color = Color(0.2, 0.16, 0.1, 0.28)
@export var zone_line_color: Color = Color(0.55, 0.42, 0.2, 0.95)
@export var zone_line_width: float = 2.0
@export_group("Hybrid Ground Visual")
@export var visual_enabled: bool = true
@export var use_animated_visual: bool = false
@export var animated_visual_is_ground: bool = false
@export var visual_texture: Texture2D = TAR_SLOW_ZONE_TEXTURE
@export var visual_modulate: Color = Color(1.0, 1.0, 1.0, 0.68)
@export var visual_shape: int = 0
@export var draw_enabled: bool = true:
	set(value):
		draw_enabled = value
		queue_redraw()
@export var ground_detail_texture: Texture2D
@export var ground_height_offset: float = 0.002
@export_group("")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var life_timer: Timer = $LifeTimer

var _field_source_id: StringName
var _slowed_players: Dictionary = {}
var _slowed_enemies: Array[BaseEnemy] = []

func _ready() -> void:
	add_to_group("enemy_runtime_cleanup")
	add_to_group(&"hybrid_ground_area_effect")
	if not get_tree().get_nodes_in_group(&"hybrid_ground_view_3d").is_empty():
		# The Hybrid Ground renderer owns the decal in 2.5D. Suppress the
		# screen-space fallback before registration to avoid a one-frame circle.
		draw_enabled = false
	call_deferred("_register_with_hybrid_ground")
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)
	_field_source_id = StringName("tar_zone_%d" % get_instance_id())
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius = maxf(radius, 1.0)
	life_timer.wait_time = maxf(duration, 0.1)
	life_timer.start()

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
	elif target is BaseEnemy:
		var enemy := target as BaseEnemy
		enemy.add_slow_field_source(self, enemy_slow_multiplier)
		if not _slowed_enemies.has(enemy):
			_slowed_enemies.append(enemy)

func _on_area_exited(area: Area2D) -> void:
	if not (area is HurtBox):
		return
	var target := _resolve_target(area as HurtBox)
	if target == null or not is_instance_valid(target):
		return
	if target is Player:
		_remove_player_slow(target as Player)
	elif target is BaseEnemy:
		var enemy := target as BaseEnemy
		enemy.remove_slow_field_source(self)
		_slowed_enemies.erase(enemy)

func _on_life_timer_timeout() -> void:
	_cleanup_all_player_slow()
	queue_free()

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
	_cleanup_all_player_slow()
	for enemy in _slowed_enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.remove_slow_field_source(self)
	_slowed_enemies.clear()

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
	if not draw_zone or not draw_enabled:
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

func _register_with_hybrid_ground() -> void:
	if not is_inside_tree():
		return
	HybridGroundRegistration.register(self, &"register_area_effect")
