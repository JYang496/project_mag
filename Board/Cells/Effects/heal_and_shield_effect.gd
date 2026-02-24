extends Node


@export var player_heal_ratio: float = 0.5
@export var enemy_damage_multiplier: float = 0.8

var _cell: Cell
var _area: Area2D
var _tracked_enemies: Array[BaseEnemy] = []
var _resisted_enemies: Dictionary = {}
var _player_healed := false

func _ready() -> void:
	_cell = get_parent() as Cell
	if not _cell:
		push_warning("CellHealAndShieldEffect must be added as a child of a Cell node.")
		return
	_cell.cell_owner_changed.connect(_on_cell_owner_changed)
	_area = _cell.get_node_or_null("Area2D")
	if _area:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("CellHealAndShieldEffect requires the parent Cell to have an Area2D child.")
	_apply_owner_state(_cell.cell_owner)

func _exit_tree() -> void:
	_clear_enemy_resistance()

func _on_cell_owner_changed(_cell_ref: Cell, _old_owner: int, new_owner: int) -> void:
	_apply_owner_state(new_owner)

func _on_body_entered(body: Node) -> void:
	if not (body is BaseEnemy):
		return
	if _tracked_enemies.has(body):
		return
	_tracked_enemies.append(body)
	if _cell and _cell.cell_owner == Cell.CellOwner.ENEMY:
		_apply_enemy_resistance(body)

func _on_body_exited(body: Node) -> void:
	if not (body is BaseEnemy):
		return
	if not _tracked_enemies.has(body):
		return
	_tracked_enemies.erase(body)
	_remove_enemy_resistance(body)

func _apply_owner_state(owner: int) -> void:
	match owner:
		Cell.CellOwner.PLAYER:
			_clear_enemy_resistance()
			if not _player_healed:
				_heal_player()
				_player_healed = true
		Cell.CellOwner.ENEMY:
			_apply_enemy_resistance_to_all()
		_:
			_clear_enemy_resistance()

func _heal_player() -> void:
	if not PlayerData.player:
		return
	var heal_amount := int(round(PlayerData.player_max_hp * player_heal_ratio))
	if heal_amount <= 0:
		return
	PlayerData.player_hp = PlayerData.player_hp + heal_amount
	_cell.effect_triggered.emit(_cell, self, PlayerData.player)

func _apply_enemy_resistance_to_all() -> void:
	for enemy in _tracked_enemies:
		_apply_enemy_resistance(enemy)

func _apply_enemy_resistance(enemy: BaseEnemy) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy_damage_multiplier <= 0:
		return
	if _resisted_enemies.has(enemy):
		return
	enemy.damage_taken_multiplier *= enemy_damage_multiplier
	_resisted_enemies[enemy] = enemy_damage_multiplier

func _remove_enemy_resistance(enemy: BaseEnemy) -> void:
	if not _resisted_enemies.has(enemy):
		return
	if is_instance_valid(enemy):
		var multiplier: float = _resisted_enemies[enemy]
		if multiplier != 0:
			enemy.damage_taken_multiplier /= multiplier
	_resisted_enemies.erase(enemy)

func _clear_enemy_resistance() -> void:
	for enemy in _resisted_enemies.keys():
		_remove_enemy_resistance(enemy)
	_resisted_enemies.clear()
