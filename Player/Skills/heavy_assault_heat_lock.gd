extends Skills
class_name HeavyAssaultHeatLock

const MOVE_SPEED_SOURCE_ID: StringName = &"heavy_assault_skill"
const RELOAD_SPEED_SOURCE_ID: StringName = &"heavy_assault_skill_reload"
const JET_VISUAL := preload("res://Player/Skills/jet_dash_visual.gd")
const DASH_SPEED_PROFILE := preload("res://Player/Skills/dash_speed_profile.gd")

@export var dash_duration_sec: float = 0.40
@export var dash_distance: float = 100.0
@export var dash_speed_curve: Curve

@export_range(1.0, 10.0, 0.01) var move_speed_multiplier: float = 1.2
@export_range(1.0, 10.0, 0.01) var reload_speed_multiplier: float = 1.3
@export var boost_duration_sec: float = 1.0
@export var base_cooldown: float = 3.0

var _boost_remaining_sec: float = 0.0
var _jet_visual: Node2D

func on_skill_ready() -> void:
	if dash_speed_curve == null:
		dash_speed_curve = DASH_SPEED_PROFILE.create_default_curve()
	cooldown = maxf(base_cooldown, 0.1)
	_jet_visual = JET_VISUAL.new()
	_player.add_child(_jet_visual)
	_player.dash_finished.connect(_on_dash_finished)
	PhaseManager.phase_changed.connect(_on_phase_changed)

func can_activate() -> bool:
	return _player != null \
		and is_instance_valid(_player) \
		and _player.has_method("apply_move_speed_mul") \
		and _player.has_method("apply_reload_speed_mul") \
		and _player.movement_enabled \
		and _player.get_movement_status().get("mode") != &"dash" \
		and _player.can_request_dash(_get_dash_direction(), dash_distance)

func activate_skill(_context: SkillActionContext) -> bool:
	if not can_activate():
		return false
	var direction := _get_dash_direction()
	if not _player.request_dash(direction, dash_distance, dash_duration_sec, MOVE_SPEED_SOURCE_ID, dash_speed_curve):
		return false
	_jet_visual.start_jet(direction, dash_duration_sec)
	_player.apply_move_speed_mul(MOVE_SPEED_SOURCE_ID, maxf(move_speed_multiplier, 1.0))
	_player.apply_reload_speed_mul(RELOAD_SPEED_SOURCE_ID, maxf(reload_speed_multiplier, 1.0))
	_boost_remaining_sec = maxf(boost_duration_sec, 0.0)
	if is_zero_approx(_boost_remaining_sec):
		_clear_skill_boosts()
	return true

func _process(delta: float) -> void:
	if _player != null and is_instance_valid(_player) and not _player.movement_enabled:
		_clear_skill_boosts()
		if is_instance_valid(_jet_visual):
			_jet_visual.stop_jet()
	if _boost_remaining_sec <= 0.0:
		return
	_boost_remaining_sec = maxf(_boost_remaining_sec - maxf(delta, 0.0), 0.0)
	if is_zero_approx(_boost_remaining_sec):
		_clear_skill_boosts()

func _exit_tree() -> void:
	_clear_skill_boosts()
	if is_instance_valid(_jet_visual):
		_jet_visual.queue_free()

func _get_dash_direction() -> Vector2:
	var direction := Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")
	if direction.length_squared() <= 0.0001:
		direction = _player.velocity
	if direction.length_squared() <= 0.0001:
		direction = _player.get_aim_world_position() - _player.global_position
	return direction.normalized()

func _on_dash_finished(_data: Dictionary) -> void:
	if is_instance_valid(_jet_visual):
		_jet_visual.release_jet()

func _on_phase_changed(_phase: String) -> void:
	_clear_skill_boosts()
	if is_instance_valid(_jet_visual):
		_jet_visual.stop_jet()

func finishes_on_commit() -> bool:
	return true

func get_skill_tags() -> Array[StringName]:
	return [&"support", &"movement", &"buff"]

func _clear_skill_boosts() -> void:
	_boost_remaining_sec = 0.0
	if _player != null and is_instance_valid(_player) and _player.has_method("remove_move_speed_mul"):
		_player.remove_move_speed_mul(MOVE_SPEED_SOURCE_ID)
	if _player != null and is_instance_valid(_player) and _player.has_method("remove_reload_speed_mul"):
		_player.remove_reload_speed_mul(RELOAD_SPEED_SOURCE_ID)
