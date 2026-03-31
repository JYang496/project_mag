extends CellAuraModule
class_name JungleAuraModule

@export var aura_jungle_vision_mul: float = 0.7

var _vision_mod_id: StringName

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if aura_jungle_vision_mul == 1.0:
		return
	player.apply_vision_mul(_get_vision_mod_id(), aura_jungle_vision_mul)

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_vision_mul(_get_vision_mod_id())

func _get_vision_mod_id() -> StringName:
	if _vision_mod_id == StringName():
		_vision_mod_id = _make_modifier_id("vision")
	return _vision_mod_id

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_jungle_vision_mul"):
		aura_jungle_vision_mul = float(params["aura_jungle_vision_mul"])
