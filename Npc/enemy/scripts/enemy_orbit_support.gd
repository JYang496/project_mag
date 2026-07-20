extends BaseEnemy
class_name EnemyOrbitSupport

@export var orbit_radius: float = 170.0
@export var orbit_correction: float = 2.5
@export var orbit_clockwise: bool = true
@export var orbit_entry_margin: float = 35.0
@export var aura_radius: float = 170.0
@export var aura_speed_bonus: float = 0.1
@export var debug_aura_detection: bool = false
@export var aura_visual_enabled: bool = true
@export var aura_fill_color: Color = Color(0.25, 0.9, 1.0, 0.14)
@export var aura_line_color: Color = Color(0.35, 0.95, 1.0, 0.8)
@export var aura_line_width: float = 2.0

@onready var speed_buff_area: Area2D = $SpeedBuffArea
@onready var speed_buff_shape: CollisionShape2D = $SpeedBuffArea/CollisionShape2D
var _buffed_targets: Array[BaseEnemy] = []

func _ready() -> void:
	super._ready()
	support_role = &"speed_support"
	EnemyRegistry.refresh_enemy_roles(self)
	add_to_group(&"hybrid_enemy_aura_source")
	call_deferred("register_hybrid_support_visuals")
	if speed_buff_shape and speed_buff_shape.shape is CircleShape2D:
		var aura_shape := speed_buff_shape.shape as CircleShape2D
		aura_shape.radius = aura_radius

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	if PlayerData.player == null:
		return
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
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

	decay_knockback()
	var desired_velocity: Vector2 = Vector2.ZERO
	if distance > orbit_radius + orbit_entry_margin:
		# Catch-up phase: close the distance to player first.
		desired_velocity = radial_dir * move_speed
	else:
		desired_velocity = orbit_velocity + radial_velocity
	move_enemy(desired_velocity, delta)

func _on_speed_buff_area_body_entered(body: Node2D) -> void:
	if debug_aura_detection:
		var script_name := ""
		if body.get_script() != null:
			script_name = body.get_script().get_global_name()
		print("[AuraEnter] engine=", body.get_class(), " script=", script_name)
	if body is BaseEnemy:
		var target := body as BaseEnemy
		if target != self and target.can_receive_support_from(self):
			target.add_speed_bonus_source(self, 1.0 + aura_speed_bonus)
			if not _buffed_targets.has(target):
				_buffed_targets.append(target)

func _on_speed_buff_area_body_exited(body: Node2D) -> void:
	if body is BaseEnemy:
		var target := body as BaseEnemy
		target.remove_speed_bonus_source(self)
		_buffed_targets.erase(target)

func _exit_tree() -> void:
	for target in _buffed_targets:
		if target != null and is_instance_valid(target):
			target.remove_speed_bonus_source(self)
	_buffed_targets.clear()
	super._exit_tree()

func _draw() -> void:
	if not aura_visual_enabled or uses_hybrid_ground_visuals():
		return
	draw_circle(Vector2.ZERO, maxf(aura_radius, 1.0), aura_fill_color)
	draw_arc(
		Vector2.ZERO,
		maxf(aura_radius, 1.0),
		0.0,
		TAU,
		56,
		aura_line_color,
		maxf(aura_line_width, 1.0),
		true
	)

func get_hybrid_aura_visual() -> Dictionary:
	return {
		"visible": aura_visual_enabled,
		"radius": aura_radius,
		"fill_color": aura_fill_color,
		"line_color": aura_line_color,
		"line_width": aura_line_width,
	}
