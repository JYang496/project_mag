extends RefCounted
class_name PlayerSkillController

var _player
var _last_player_skill_fail_reason: String = ""

func setup(player) -> void:
	_player = player

func setup_default_active_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.active_skill_holder == null:
		push_warning("ActiveSkill node is missing, default active skill will not be loaded.")
		return
	if _player.active_skill_holder.get_child_count() > 0:
		return
	var scene_path := str(_player.default_active_skill_path)
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	var scene_resource := load(scene_path)
	var skill_scene := scene_resource as PackedScene
	if skill_scene == null:
		push_warning("Failed to load default active skill scene: %s" % scene_path)
		return
	var skill_instance := skill_scene.instantiate()
	if not (skill_instance is Skills):
		push_warning("Default active skill must inherit Skills: %s" % scene_path)
		return
	_player.active_skill_holder.add_child(skill_instance)

func try_cast_player_active_skill() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.player_active_skill.emit()
	_player.active_skill.emit()
	_last_player_skill_fail_reason = ""

func get_last_player_skill_fail_reason() -> String:
	return _last_player_skill_fail_reason
