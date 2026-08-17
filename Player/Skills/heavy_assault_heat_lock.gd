extends Skills
class_name HeavyAssaultHeatLock

const MOVE_SPEED_SOURCE_ID: StringName = &"heavy_assault_skill"
const RELOAD_SPEED_SOURCE_ID: StringName = &"heavy_assault_skill_reload"

@export_range(1.0, 10.0, 0.01) var move_speed_multiplier: float = 1.2
@export_range(1.0, 10.0, 0.01) var reload_speed_multiplier: float = 1.3
@export var boost_duration_sec: float = 1.0
@export var base_cooldown: float = 3.0

var _boost_remaining_sec: float = 0.0

func on_skill_ready() -> void:
	cooldown = maxf(base_cooldown, 0.1)

func can_activate() -> bool:
	return _player != null \
		and is_instance_valid(_player) \
		and _player.has_method("apply_move_speed_mul") \
		and _player.has_method("apply_reload_speed_mul")

func activate_skill(_context: SkillActionContext) -> bool:
	if not can_activate():
		return false
	_player.apply_move_speed_mul(MOVE_SPEED_SOURCE_ID, maxf(move_speed_multiplier, 1.0))
	_player.apply_reload_speed_mul(RELOAD_SPEED_SOURCE_ID, maxf(reload_speed_multiplier, 1.0))
	_boost_remaining_sec = maxf(boost_duration_sec, 0.0)
	if is_zero_approx(_boost_remaining_sec):
		_clear_skill_boosts()
	return true

func _process(delta: float) -> void:
	if _boost_remaining_sec <= 0.0:
		return
	_boost_remaining_sec = maxf(_boost_remaining_sec - maxf(delta, 0.0), 0.0)
	if is_zero_approx(_boost_remaining_sec):
		_clear_skill_boosts()

func _exit_tree() -> void:
	_clear_skill_boosts()

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
