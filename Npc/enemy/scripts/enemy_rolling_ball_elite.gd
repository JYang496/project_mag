extends EliteEnemy
class_name EnemyEliteRollingBall

@onready var skill_area: Area2D = $SkillArea
@onready var skill_warning_telegraph: SkillWarningTelegraph = $SkillWarningTelegraph
@export var dash_speed_multiplier: float = 15.0
@export var dash_distance: float = 700.0
@export var charge_duration: float = 1.0
@export var warning_half_width: float = 36.0
var bonus_speed:float = 0
var charging : bool = false
var preparing_dash: bool = false
var player_in_range : bool = false
var dash_remaining_distance: float = 0.0
var charge_elapsed: float = 0.0
@onready var direction = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_stunned():
		if preparing_dash:
			_update_dash_prepare(delta)
		knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
		velocity = knockback.amount * knockback.angle
		move_and_slide()
		return
	if not charging:
		direction = global_position.direction_to(PlayerData.player.global_position)
	if preparing_dash:
		_update_dash_prepare(delta)
	knockback.amount = clamp(knockback.amount - knockback_recover, 0, knockback.amount)
	velocity = direction * (get_current_movement_speed() + bonus_speed)
	velocity += knockback.amount * knockback.angle
	var previous_position := global_position
	move_and_slide()
	if charging:
		var moved_distance := global_position.distance_to(previous_position)
		dash_remaining_distance -= moved_distance
		if dash_remaining_distance <= 0.0 or moved_distance <= 0.001:
			_finish_dash()

func _on_skill_timer_timeout() -> void:
	skill_ready = true


func _on_detect_timer_timeout() -> void:
	if not skill_ready or charging or preparing_dash:
		return
	if player_in_range:
		_start_dash_prepare()

func _on_skill_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true

func _on_skill_area_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false

func _finish_dash() -> void:
	if not charging and not preparing_dash:
		return
	highlight_material.set_shader_parameter("outline_color", Color.YELLOW)
	self.set_collision_mask_value(3,true)
	charging = false
	preparing_dash = false
	bonus_speed = 0.0
	dash_remaining_distance = 0.0
	charge_elapsed = 0.0
	if skill_warning_telegraph:
		skill_warning_telegraph.clear_warning()
	skill_timer.start()

func _start_dash_prepare() -> void:
	skill_ready = false
	preparing_dash = true
	charge_elapsed = 0.0
	if PlayerData.player and direction == Vector2.ZERO:
		direction = global_position.direction_to(PlayerData.player.global_position)
	bonus_speed = -0.7 * movement_speed
	highlight_material.set_shader_parameter("outline_color", Color.RED)
	self.set_collision_mask_value(3,false)
	if skill_warning_telegraph:
		skill_warning_telegraph.show_dash_warning(
			global_position,
			direction,
			dash_distance,
			charge_duration,
			warning_half_width
		)

func _update_dash_prepare(delta: float) -> void:
	charge_elapsed += maxf(0.0, delta)
	if skill_warning_telegraph:
		skill_warning_telegraph.update_dash_warning(global_position, direction, delta)
	if charge_elapsed < charge_duration:
		return
	_begin_dash()

func _begin_dash() -> void:
	preparing_dash = false
	charging = true
	bonus_speed = dash_speed_multiplier * movement_speed
	dash_remaining_distance = dash_distance
	charge_elapsed = 0.0
	if skill_warning_telegraph:
		skill_warning_telegraph.clear_warning()
