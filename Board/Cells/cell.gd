extends Node2D
class_name Cell

signal cell_state_changed(cell: Cell, old_state: int, new_state: int)
signal cell_owner_changed(cell: Cell, old_owenr: int, new_owener: int)
signal effect_triggered(cell: Cell, effect: Node, actor: Node)

enum CellState {IDLE, PLAYER, ENEMY, CONTESTED, LOCKED}
enum CellOwner {NONE, PLAYER, ENEMY}

var state: int = CellState.IDLE : set = set_state
var cell_owner: int = CellOwner.NONE : set = set_cell_owner
var _player_bodies: Array[Node2D] = []
var _enemy_bodies: Array[Node2D] = []
var progress: int = 0
@onready var _sprite: Sprite2D = $Texture/Sprite2D
var _default_color: Color = Color.WHITE
var _is_highlighted := false
var _pending_highlight_color: Color = Color.WHITE
var _has_pending_highlight := false

const PROGRESS_INTERVAL := 0.2
const PROGRESS_STEP := 1
const PROGRESS_LIMIT := 100
const CAPTURE_THRESHOLD := 50

var _progress_timer: Timer

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
	var old = cell_owner
	cell_owner = value
	cell_owner_changed.emit(self, old, cell_owner)
	_update_visual_by_owner()

func _ready() -> void:
	if _sprite:
		_default_color = _sprite.modulate
	if _is_highlighted and _has_pending_highlight and _sprite:
		_sprite.modulate = _pending_highlight_color
		_has_pending_highlight = false
	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_INTERVAL
	_progress_timer.autostart = true
	_progress_timer.one_shot = false
	add_child(_progress_timer)
	_progress_timer.timeout.connect(_on_progress_timer_timeout)

func _update_visual_by_state() -> void:
	pass

func _update_visual_by_owner() -> void:
	if not _sprite or _is_highlighted:
		return
	match cell_owner:
		CellOwner.PLAYER:
			_sprite.modulate = Color(0.6, 0.8, 1.0)
		CellOwner.ENEMY:
			_sprite.modulate = Color(1.0, 0.4, 0.4)
		_:
			_sprite.modulate = _default_color

func set_highlight_color(color: Color) -> void:
	_is_highlighted = true
	if not _sprite:
		_pending_highlight_color = color
		_has_pending_highlight = true
		return
	_has_pending_highlight = false
	_sprite.modulate = color

func clear_highlight() -> void:
	if not _sprite:
		_is_highlighted = false
		_has_pending_highlight = false
		return
	_is_highlighted = false
	_update_visual_by_owner()

func _evaluate_cell_state() -> void:
	if state == CellState.LOCKED:
		return
	var player_present := not _player_bodies.is_empty()
	var enemy_present := not _enemy_bodies.is_empty()
	if player_present and enemy_present:
		set_state(CellState.CONTESTED)
	elif player_present:
		set_state(CellState.PLAYER)
	elif enemy_present:
		set_state(CellState.ENEMY)
	else:
		set_state(CellState.IDLE)

func _on_progress_timer_timeout() -> void:
	if state == CellState.LOCKED:
		return
	var delta := 0
	if state == CellState.PLAYER:
		delta = PROGRESS_STEP
	elif state == CellState.ENEMY:
		delta = -PROGRESS_STEP
	if delta == 0:
		return
	progress = clamp(progress + delta, -PROGRESS_LIMIT, PROGRESS_LIMIT)
	var new_owner := cell_owner
	if progress >= CAPTURE_THRESHOLD:
		new_owner = CellOwner.PLAYER
	elif progress <= -CAPTURE_THRESHOLD:
		new_owner = CellOwner.ENEMY
	else:
		new_owner = CellOwner.NONE
	set_cell_owner(new_owner)

# Body with layer 5 can be detected
func _on_area_2d_body_entered(body: Node2D) -> void:
	var state_changed := false
	if body is Player and not _player_bodies.has(body):
		_player_bodies.append(body)
		state_changed = true
	elif body is BaseEnemy and not _enemy_bodies.has(body):
		_enemy_bodies.append(body)
		state_changed = true
	if state_changed:
		_evaluate_cell_state()


func _on_area_2d_body_exited(body: Node2D) -> void:
	var state_changed := false
	if body is Player and _player_bodies.has(body):
		_player_bodies.erase(body)
		state_changed = true
	elif body is BaseEnemy and _enemy_bodies.has(body):
		_enemy_bodies.erase(body)
		state_changed = true
	if state_changed:
		_evaluate_cell_state()
