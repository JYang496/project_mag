extends BaseEnemy
class_name EnemyMirrorCaster

const MIRROR_CLONE_SCENE := preload("res://Npc/enemy/scenes/enemy_mirror_clone.tscn")

@export var cast_cooldown: float = 5.5
@export var cast_time: float = 0.9
@export var mirror_count: int = 2
@export var mirror_duration: float = 6.0
@export var mirror_spawn_radius: float = 95.0
@export var reposition_distance: float = 180.0
@export var cast_range: float = 480.0

var _cooldown_remaining: float = 1.8
var _is_casting: bool = false
var _cast_remaining: float = 0.0

func _physics_process(delta: float) -> void:
	if is_stunned():
		knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	if PlayerData.player == null:
		return
	_process_casting(delta)
	var direction := global_position.direction_to(PlayerData.player.global_position)
	knockback.amount = clampf(knockback.amount - knockback_recover, 0.0, knockback.amount)
	var move_speed := get_current_movement_speed() * (0.45 if _is_casting else 0.85)
	velocity = direction * move_speed + knockback.amount * knockback.angle
	move_and_slide()

func _process_casting(delta: float) -> void:
	if _is_casting:
		_cast_remaining -= maxf(delta, 0.0)
		if _cast_remaining <= 0.0:
			_finish_cast()
		return
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
		return
	if PlayerData.player.global_position.distance_to(global_position) > cast_range:
		return
	_start_cast()

func _start_cast() -> void:
	_is_casting = true
	_cast_remaining = maxf(cast_time, 0.1)

func _finish_cast() -> void:
	_is_casting = false
	_cooldown_remaining = maxf(cast_cooldown, 0.2)
	_spawn_mirrors()
	_reposition()

func _spawn_mirrors() -> void:
	var count := clampi(mirror_count, 1, 4)
	for i in range(count):
		var clone := MIRROR_CLONE_SCENE.instantiate() as EnemyMirrorClone
		if clone == null:
			continue
		var angle := randf() * TAU
		var distance := randf_range(20.0, maxf(mirror_spawn_radius, 20.0))
		clone.global_position = global_position + Vector2.RIGHT.rotated(angle) * distance
		clone.life_time = mirror_duration
		clone.hp = max(4, int(round(float(max(1, hp)) * 0.22)))
		clone.damage = max(1, int(round(float(max(1, damage)) * 0.6)))
		clone.movement_speed = movement_speed * 1.05
		call_deferred("add_sibling", clone)

func _reposition() -> void:
	var angle := randf() * TAU
	var distance := randf_range(maxf(reposition_distance * 0.5, 40.0), maxf(reposition_distance, 60.0))
	global_position += Vector2.RIGHT.rotated(angle) * distance
