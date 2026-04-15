extends BaseEnemy
class_name EnemySpikeTurret

const PROJECTILE_SCENE := preload("res://Npc/enemy/scenes/enemy_spike_projectile.tscn")

@export var attack_range: float = 430.0
@export var lock_duration: float = 1.1
@export var cooldown_duration: float = 1.9
@export var projectile_speed: float = 190.0
@export var projectile_life_time: float = 3.2
@export var muzzle_offset: float = 22.0

var _cooldown_remaining: float = 0.0
var _lock_remaining: float = 0.0
var _is_locking: bool = false
var _locked_direction: Vector2 = Vector2.RIGHT

func _physics_process(delta: float) -> void:
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	velocity = knockback.amount * knockback.angle
	move_and_slide()
	if is_stunned():
		return
	_process_attack(delta)

func _process_attack(delta: float) -> void:
	if PlayerData.player == null:
		return
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		return
	var to_player := PlayerData.player.global_position - global_position
	if not _is_locking:
		if to_player.length() > attack_range:
			return
		_locked_direction = to_player.normalized() if to_player.length() > 0.001 else Vector2.RIGHT
		_is_locking = true
		_lock_remaining = lock_duration
		return
	_lock_remaining -= delta
	if _lock_remaining > 0.0:
		return
	_fire_projectile()
	_is_locking = false
	_cooldown_remaining = cooldown_duration

func _fire_projectile() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as EnemySpikeProjectile
	if projectile == null:
		return
	projectile.global_position = global_position + _locked_direction * muzzle_offset
	projectile.direction = _locked_direction
	projectile.speed = projectile_speed
	projectile.life_time = projectile_life_time
	projectile.damage = max(1, damage)
	projectile.source_enemy = self
	call_deferred("add_sibling", projectile)
