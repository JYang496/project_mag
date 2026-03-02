extends CellAuraModule
class_name SpeedBoostAuraModule

@export var move_speed_mul: float = 1.2

var _move_mod_id: StringName

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if move_speed_mul == 1.0:
		return
	player.apply_move_speed_mul(_get_move_mod_id(), move_speed_mul)

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_move_speed_mul(_get_move_mod_id())

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_speed_move_speed_mul"):
		move_speed_mul = float(params["aura_speed_move_speed_mul"])

func _get_move_mod_id() -> StringName:
	if _move_mod_id == StringName():
		_move_mod_id = _make_modifier_id("speed_boost")
	return _move_mod_id
