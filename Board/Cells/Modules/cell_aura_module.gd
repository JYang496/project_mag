extends Node
class_name CellAuraModule

@export var aura_enabled := false

var _cell: Cell
var _area: Area2D
var _inside_players: Array[Player] = []

func _ready() -> void:
	_cell = get_parent().get_parent() as Cell if get_parent() and get_parent().name == "Modules" else get_parent() as Cell
	if _cell == null:
		push_warning("CellAuraModule must be a child of Cell or Cell/Modules.")
		return
	_area = _cell.get_node_or_null("Area2D")
	if _area == null:
		push_warning("CellAuraModule cannot find Area2D on Cell.")
		return
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
		_apply_aura_to_player(player)

func _on_body_exited(body: Node) -> void:
	if body is Player:
		var player := body as Player
		if not _inside_players.has(player):
			return
		_remove_aura_from_player(player)
		_inside_players.erase(player)

func _apply_aura_to_player(_player: Player) -> void:
	pass

func _remove_aura_from_player(_player: Player) -> void:
	pass

func _clear_all_players() -> void:
	for player in _inside_players:
		_remove_aura_from_player(player)
	_inside_players.clear()

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
			_apply_aura_to_player(player)

func _make_modifier_id(tag: String) -> StringName:
	var cell_name: String = _cell.name if _cell else "Cell"
	return StringName("%s_%s_%s" % [cell_name, tag, str(get_instance_id())])
