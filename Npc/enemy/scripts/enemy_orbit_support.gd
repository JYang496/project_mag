extends BaseEnemy
class_name EnemyOrbitSupport

const META_AURA_SOURCES := "_speed_aura_sources"
const META_AURA_BASE_SPEED := "_speed_aura_base_speed"

@export var orbit_radius: float = 170.0
@export var orbit_correction: float = 2.5
@export var orbit_clockwise: bool = true
@export var orbit_entry_margin: float = 35.0
@export var aura_radius: float = 170.0
@export var aura_speed_bonus: float = 0.1
@export var debug_aura_detection: bool = false

@onready var speed_buff_area: Area2D = $SpeedBuffArea
@onready var speed_buff_shape: CollisionShape2D = $SpeedBuffArea/CollisionShape2D

var _buffed_targets: Array[BaseEnemy] = []

func _ready() -> void:
	super._ready()
	if speed_buff_shape and speed_buff_shape.shape is CircleShape2D:
		var aura_shape := speed_buff_shape.shape as CircleShape2D
		aura_shape.radius = aura_radius

func _physics_process(delta: float) -> void:
	if PlayerData.player == null:
		return
	if is_stunned():
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		_sync_aura_overlaps()
		return

	var to_player: Vector2 = PlayerData.player.global_position - global_position
	var distance: float = to_player.length()
	var radial_dir: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	var tangent: Vector2 = Vector2(-radial_dir.y, radial_dir.x)
	var orbit_sign: float = -1.0 if orbit_clockwise else 1.0
	var move_speed: float = get_current_movement_speed()

	var radial_error: float = distance - orbit_radius
	var radial_velocity: Vector2 = radial_dir * radial_error * orbit_correction
	var orbit_velocity: Vector2 = tangent * move_speed * orbit_sign

	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	if distance > orbit_radius + orbit_entry_margin:
		# Catch-up phase: close the distance to player first.
		velocity = radial_dir * move_speed
	else:
		velocity = orbit_velocity + radial_velocity
	velocity += knockback.amount * knockback.angle
	move_and_slide()
	_sync_aura_overlaps()

func _on_speed_buff_area_body_entered(body: Node2D) -> void:
	if debug_aura_detection:
		var script_name := ""
		if body.get_script() != null:
			script_name = body.get_script().get_global_name()
		print("[AuraEnter] engine=", body.get_class(), " script=", script_name)
	if body is BaseEnemy:
		_apply_speed_aura(body)

func _on_speed_buff_area_body_exited(body: Node2D) -> void:
	if body is BaseEnemy:
		_remove_speed_aura(body)

func _sync_aura_overlaps() -> void:
	if speed_buff_area == null:
		return
	for body in speed_buff_area.get_overlapping_bodies():
		if body is BaseEnemy:
			_apply_speed_aura(body)
	for target in _buffed_targets.duplicate():
		if not is_instance_valid(target):
			_remove_speed_aura(target)
			continue
		if not speed_buff_area.overlaps_body(target):
			_remove_speed_aura(target)

func _exit_tree() -> void:
	for target in _buffed_targets.duplicate():
		_remove_speed_aura(target)

func _apply_speed_aura(target_ref) -> void:
	if target_ref == null:
		return
	if not is_instance_valid(target_ref):
		return

	var target := target_ref as BaseEnemy
	if target == self or target is EnemyOrbitSupport:
		return

	var source_id := get_instance_id()
	var sources = target.get_meta(META_AURA_SOURCES, [])
	if not (sources is Array):
		sources = []

	if not sources.has(source_id):
		sources.append(source_id)
	target.set_meta(META_AURA_SOURCES, sources)

	if not target.has_meta(META_AURA_BASE_SPEED):
		target.set_meta(META_AURA_BASE_SPEED, target.movement_speed)

	var base_speed := float(target.get_meta(META_AURA_BASE_SPEED))
	target.movement_speed = base_speed * (1.0 + aura_speed_bonus)

	if not _buffed_targets.has(target):
		_buffed_targets.append(target)

func _remove_speed_aura(target_ref) -> void:
	if target_ref == null:
		return
	if not is_instance_valid(target_ref):
		_buffed_targets.erase(target_ref)
		return

	var target := target_ref as BaseEnemy
	if target == null:
		_buffed_targets.erase(target_ref)
		return

	var source_id := get_instance_id()
	var sources = target.get_meta(META_AURA_SOURCES, [])
	if not (sources is Array):
		sources = []

	if sources.has(source_id):
		sources.erase(source_id)

	if sources.is_empty():
		if target.has_meta(META_AURA_BASE_SPEED):
			target.movement_speed = float(target.get_meta(META_AURA_BASE_SPEED))
			target.remove_meta(META_AURA_BASE_SPEED)
		target.remove_meta(META_AURA_SOURCES)
	else:
		target.set_meta(META_AURA_SOURCES, sources)
		var base_speed := float(target.get_meta(META_AURA_BASE_SPEED, target.movement_speed))
		target.movement_speed = base_speed * (1.0 + aura_speed_bonus)

	_buffed_targets.erase(target)
