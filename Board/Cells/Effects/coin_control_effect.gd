extends Node
class_name CellCoinControlEffect

@export var initial_drop_amount: int = 10
@export var drain_interval: float = 1.0
@export var drain_amount: int = 1

const DROP_SCENE := preload("res://Objects/loots/drop.tscn")
const COIN_SCENE := preload("res://Objects/loots/coin.tscn")

var _cell: Cell
var _drain_timer: Timer
var _player_drop_triggered := false
var _coins_to_refund: int = 0

func _ready() -> void:
	_cell = get_parent() as Cell
	if not _cell:
		push_warning("CellCoinControlEffect must be a child of a Cell node.")
		return
	_cell.cell_owner_changed.connect(_on_cell_owner_changed)
	_setup_drain_timer()
	_apply_owner_state(_cell.cell_owner)

func _exit_tree() -> void:
	_stop_drain()
	_refund_coins()

func _setup_drain_timer() -> void:
	_drain_timer = Timer.new()
	_drain_timer.wait_time = max(drain_interval, 0.1)
	_drain_timer.autostart = false
	_drain_timer.one_shot = false
	add_child(_drain_timer)
	_drain_timer.timeout.connect(_on_drain_timeout)

func _on_cell_owner_changed(_cell_ref: Cell, _old_owner: int, new_owner: int) -> void:
	_apply_owner_state(new_owner)

func _apply_owner_state(owner: int) -> void:
	match owner:
		Cell.CellOwner.PLAYER:
			_stop_drain()
			_drop_coins_once()
			_refund_coins()
		Cell.CellOwner.ENEMY:
			_start_drain()
		_:
			_stop_drain()

func _start_drain() -> void:
	if not _drain_timer:
		return
	if _drain_timer.is_stopped():
		_drain_timer.start()

func _stop_drain() -> void:
	if _drain_timer and not _drain_timer.is_stopped():
		_drain_timer.stop()

func _on_drain_timeout() -> void:
	if drain_amount <= 0:
		return
	if PlayerData.player_gold <= 0:
		return
	var amount: int = int(min(drain_amount, PlayerData.player_gold))
	PlayerData.player_gold -= amount
	_coins_to_refund += amount

func _drop_coins_once() -> void:
	if _player_drop_triggered:
		return
	_player_drop_triggered = true
	_spawn_coin_drop(initial_drop_amount)

func _spawn_coin_drop(amount: int) -> void:
	if amount <= 0 or not _cell:
		return
	PlayerData.player_gold += amount
	var actor: Node = PlayerData.player if PlayerData.player else _cell
	_cell.effect_triggered.emit(_cell, self, actor)

func _refund_coins() -> void:
	if _coins_to_refund <= 0:
		return
	PlayerData.player_gold += _coins_to_refund
	_coins_to_refund = 0
