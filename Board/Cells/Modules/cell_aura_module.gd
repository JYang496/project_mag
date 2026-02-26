extends Node
class_name CellAuraModule

@export var aura_enabled := false
@export var terrain_override: int = -1
@export var move_speed_mul: float = 1.0
@export var vision_mul: float = 1.0

var _cell: Cell
var _area: Area2D
var _inside_players: Array[Player] = []
var _move_mod_id: StringName
var _vision_mod_id: StringName

func _ready() -> void:
	_cell = get_parent().get_parent() as Cell if get_parent() and get_parent().name == "Modules" else get_parent() as Cell
	if _cell == null:
		push_warning("CellAuraModule must be a child of Cell or Cell/Modules.")
		return
	_area = _cell.get_node_or_null("Area2D")
	if _area == null:
		push_warning("CellAuraModule cannot find Area2D on Cell.")
		return
	_move_mod_id = StringName("%s_move_%s" % [_cell.name, str(get_instance_id())])
	_vision_mod_id = StringName("%s_vision_%s" % [_cell.name, str(get_instance_id())])
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	if not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func _exit_tree() -> void:
	_clear_all_players()
	if PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.disconnect("phase_changed", Callable(self, "_on_phase_changed"))

func _on_body_entered(body: Node) -> void:
	if not aura_enabled and not _cell.aura_enabled:
		return
	if not _is_active_phase():
		return
	if body is Player:
		var player := body as Player
		if _inside_players.has(player):
			return
		_inside_players.append(player)
		_apply_to_player(player)

func _on_body_exited(body: Node) -> void:
	if body is Player:
		var player := body as Player
		if not _inside_players.has(player):
			return
		_remove_from_player(player)
		_inside_players.erase(player)

func _apply_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if _get_terrain_type() == Cell.TerrainType.CORROSION and move_speed_mul != 1.0:
		player.apply_move_speed_mul(_move_mod_id, move_speed_mul)
	if _get_terrain_type() == Cell.TerrainType.JUNGLE and vision_mul != 1.0:
		player.apply_vision_mul(_vision_mod_id, vision_mul)

func _remove_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	player.remove_move_speed_mul(_move_mod_id)
	player.remove_vision_mul(_vision_mod_id)

func _clear_all_players() -> void:
	for player in _inside_players:
		_remove_from_player(player)
	_inside_players.clear()

func _get_terrain_type() -> int:
	return terrain_override if terrain_override >= 0 else _cell.terrain_type

func _is_active_phase() -> bool:
	return PhaseManager.current_state() == PhaseManager.BATTLE

func _on_phase_changed(new_phase: String) -> void:
	if new_phase != PhaseManager.BATTLE:
		_clear_all_players()
		return
	_refresh_players_in_area()

func _refresh_players_in_area() -> void:
	if _area == null:
		return
	for body in _area.get_overlapping_bodies():
		if body is Player:
			var player := body as Player
			if not _inside_players.has(player):
				_inside_players.append(player)
			_apply_to_player(player)
