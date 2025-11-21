extends Node2D
class_name Cell

signal cell_state_changed(cell: Cell, old_state: int, new_state: int)
signal cell_owner_changed(cell: Cell, old_owenr: int, new_owener: int)
signal effect_triggered(cell: Cell, effect: Resource, actor: Node)

enum CellState {IDLE, CONTESTED, LOCKED}
enum CellOwner {NONE, PLAYER, ENEMY}

var state: int = CellState.IDLE : set = set_state
var cell_owner: int = CellOwner.NONE : set = set_cell_owner

func set_state(value: int) -> void:
	if state == value:
		return
	var old = state
	state = value
	cell_state_changed.emit(self, old, state)
	_update_visual_by_state()

func set_cell_owner(value: int) -> void:
	if cell_owner == value:
		return
	var old = owner
	cell_owner = value
	cell_owner_changed.emit(self, old, owner)
	_update_visual_by_owner()

func _update_visual_by_state() -> void:
	pass

func _update_visual_by_owner() -> void:
	pass

# Body with layer 5 can be detected
func _on_area_2d_body_entered(body: Node2D) -> void:
	prints(self,"Body enter",body)


func _on_area_2d_body_exited(body: Node2D) -> void:
	prints(self,"Body exit",body)
