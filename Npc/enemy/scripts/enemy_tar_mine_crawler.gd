extends EnemyMineCrawler
class_name EnemyTarMineCrawler

const TAR_ZONE_SCENE := preload("res://Npc/enemy/scenes/tar_slow_zone.tscn")

@export var tar_duration: float = 4.0
@export var tar_radius: float = 95.0
@export var tar_player_slow_multiplier: float = 0.65
@export var tar_enemy_slow_multiplier: float = 0.65

func death(killing_attack: Attack = null) -> void:
	_spawn_tar_zone()
	_finalize_death(killing_attack)

func _spawn_tar_zone() -> void:
	var zone := TAR_ZONE_SCENE.instantiate() as EnemyTarSlowZone
	if zone == null:
		return
	zone.global_position = global_position
	zone.duration = tar_duration
	zone.radius = tar_radius
	zone.player_slow_multiplier = tar_player_slow_multiplier
	zone.enemy_slow_multiplier = tar_enemy_slow_multiplier
	call_deferred("add_sibling", zone)
