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
	if is_stunned():
		knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	if PlayerData.player == null:
		return
	var base_speed := get_current_movement_speed()
	var max_speed := base_speed * maxf(max_speed_multiplier, 1.0)
	_current_speed = minf(_current_speed + chase_acceleration * delta, max_speed)
	var direction := global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	velocity = direction * _current_speed + knockback.amount * knockback.angle
	move_and_slide()

func death(killing_attack: Attack = null) -> void:
	if not is_inside_tree():
		_finalize_death(killing_attack)
		return
	var zone := SLOW_ZONE_SCENE.instantiate() as EnemyTarSlowZone
	if zone:
		zone.global_position = global_position
		zone.duration = maxf(death_aoe_duration, 0.1)
		zone.radius = maxf(blast_radius, 6.0)
		zone.player_slow_multiplier = clampf(death_player_slow_multiplier, 0.05, 1.0)
		zone.enemy_slow_multiplier = clampf(death_enemy_slow_multiplier, 0.05, 1.0)
		call_deferred("add_sibling", zone)
	_finalize_death(killing_attack)

func _finalize_death(killing_attack: Attack = null) -> void:
	super.death(killing_attack)
