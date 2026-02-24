extends Node


@export var speed_bonus: float = 45.0

var _cell: Cell
var _area: Area2D
var _player_bonus_active := false
var _overlapping_players: Array[Player] = []
var _overlapping_enemies: Array[BaseEnemy] = []
var _buffed_enemies: Dictionary = {}

func _ready() -> void:
	_cell = get_parent() as Cell
	if not _cell:
		push_warning("CellSpeedBoostEffect must be added as a child of a Cell node.")
		return
	_cell.cell_owner_changed.connect(_on_cell_owner_changed)
	_area = _cell.get_node_or_null("Area2D")
	if not _area:
		push_warning("CellSpeedBoostEffect could not find Area2D on parent Cell.")
		return
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _exit_tree() -> void:
	_clear_player_bonus()
	_clear_enemy_bonuses()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		if _overlapping_players.has(body):
			return
		_overlapping_players.append(body)
	elif body is BaseEnemy:
		if _overlapping_enemies.has(body):
			return
		_overlapping_enemies.append(body)
	else:
		return
	_update_bonuses()

func _on_body_exited(body: Node) -> void:
	if body is Player:
		if not _overlapping_players.has(body):
			return
		_overlapping_players.erase(body)
	elif body is BaseEnemy:
		if not _overlapping_enemies.has(body):
			return
		_overlapping_enemies.erase(body)
		_remove_enemy_bonus(body)
	else:
		return
	_update_bonuses()

func _on_cell_owner_changed(_cell_ref: Cell, _old_owner: int, _new_owner: int) -> void:
	_update_bonuses()

func _update_bonuses() -> void:
	if not _cell:
		return
	match _cell.cell_owner:
		Cell.CellOwner.PLAYER:
			if _overlapping_players.is_empty():
				_clear_player_bonus()
			else:
				_apply_player_bonus()
			_clear_enemy_bonuses()
		Cell.CellOwner.ENEMY:
			_clear_player_bonus()
			if _overlapping_enemies.is_empty():
				_clear_enemy_bonuses()
			else:
				_apply_enemy_bonuses()
		_:
			_clear_player_bonus()
			_clear_enemy_bonuses()

func _apply_player_bonus() -> void:
	if _player_bonus_active or PlayerData.player == null:
		return
	PlayerData.player_bonus_speed += speed_bonus
	_player_bonus_active = true
	_cell.effect_triggered.emit(_cell, self, PlayerData.player)

func _clear_player_bonus() -> void:
	if not _player_bonus_active:
		return
	PlayerData.player_bonus_speed -= speed_bonus
	_player_bonus_active = false

func _apply_enemy_bonuses() -> void:
	for enemy in _overlapping_enemies:
		_apply_enemy_bonus(enemy)

func _apply_enemy_bonus(enemy: BaseEnemy) -> void:
	if not is_instance_valid(enemy):
		return
	if _buffed_enemies.has(enemy):
		return
	enemy.movement_speed += speed_bonus
	_buffed_enemies[enemy] = speed_bonus
	_cell.effect_triggered.emit(_cell, self, enemy)

func _clear_enemy_bonuses() -> void:
	for enemy in _buffed_enemies.keys():
		_remove_enemy_bonus(enemy)
	_buffed_enemies.clear()

func _remove_enemy_bonus(enemy: BaseEnemy) -> void:
	if not _buffed_enemies.has(enemy):
		return
	if is_instance_valid(enemy):
		enemy.movement_speed -= _buffed_enemies[enemy]
	_buffed_enemies.erase(enemy)
