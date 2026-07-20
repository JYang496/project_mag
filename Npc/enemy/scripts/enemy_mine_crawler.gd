extends BaseEnemy
class_name EnemyMineCrawler

const SLOW_ZONE_SCENE := preload("res://Npc/enemy/scenes/tar_slow_zone.tscn")

@export var chase_acceleration: float = 22.0
@export var max_speed_multiplier: float = 1.4
@export var blast_radius: float = 58.0
@export var death_aoe_duration: float = 10.0
@export var death_player_slow_multiplier: float = 0.7
@export var death_enemy_slow_multiplier: float = 0.7

var _current_speed: float = 0.0

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
		return
	if PlayerData.player == null:
		return
	var base_speed := get_current_movement_speed()
	var max_speed := base_speed * maxf(max_speed_multiplier, 1.0)
	_current_speed = minf(_current_speed + chase_acceleration * delta, max_speed)
	var direction := global_position.direction_to(PlayerData.player.global_position)
	decay_knockback()
	move_enemy(direction * _current_speed, delta)

func _before_death(_killing_attack: Attack) -> void:
	if not is_inside_tree():
		return
	var zone := SLOW_ZONE_SCENE.instantiate() as EnemyTarSlowZone
	if zone:
		zone.global_position = global_position
		zone.duration = maxf(death_aoe_duration, 0.1)
		zone.radius = maxf(blast_radius, 6.0)
		zone.player_slow_multiplier = clampf(death_player_slow_multiplier, 0.05, 1.0)
		zone.enemy_slow_multiplier = clampf(death_enemy_slow_multiplier, 0.05, 1.0)
		call_deferred("add_sibling", zone)
