extends CellObjectiveModule
class_name OffenseKillObjectiveModule

@export var required_kill_count: int = 10
@export var count_kill_only_when_player_inside := true

var _kill_count := 0
var _last_debug_snapshot := ""
var _enemy_death_callbacks: Dictionary = {}
var _counted_enemy_ids: Dictionary = {}

func _ready() -> void:
	super._ready()
	_connect_enemy_registry()
	_refresh_tracked_enemies()

func _exit_tree() -> void:
	_disconnect_enemy_registry()
	_clear_tracked_enemies()
	super._exit_tree()

func set_task_parameters(params: Dictionary) -> void:
	if params.has("required_kill_count"):
		required_kill_count = params["required_kill_count"]
	if params.has("count_kill_only_when_player_inside"):
		count_kill_only_when_player_inside = params["count_kill_only_when_player_inside"]
	_emit_task_status_changed()

func reset_objective_runtime() -> void:
	super.reset_objective_runtime()
	_kill_count = 0
	_last_debug_snapshot = ""
	_counted_enemy_ids.clear()
	_refresh_tracked_enemies()
	_emit_task_status_changed()

func get_combat_task_status() -> Dictionary:
	var required := maxi(required_kill_count, 1)
	var progress := float(_kill_count) / float(required)
	var value_text := "%d/%d" % [mini(_kill_count, required), required]
	return _build_combat_task_status("kill", "kill", "击杀", progress, value_text, _kill_count > 0)

func _on_objective_enemy_killed(enemy: BaseEnemy) -> void:
	_count_enemy_kill(enemy)

func _count_enemy_kill(enemy: BaseEnemy) -> void:
	if enemy == null:
		return
	var enemy_id := enemy.get_instance_id()
	if _counted_enemy_ids.has(enemy_id):
		return
	_counted_enemy_ids[enemy_id] = true
	if count_kill_only_when_player_inside and not _cell.has_player_inside():
		return
	_kill_count += 1
	_emit_task_status_changed()
	if _kill_count >= required_kill_count:
		_complete_objective()

func _connect_enemy_registry() -> void:
	var registry := _get_enemy_registry()
	if registry == null:
		return
	if registry.has_signal("enemy_registered") and not registry.enemy_registered.is_connected(_on_enemy_registered):
		registry.enemy_registered.connect(_on_enemy_registered)
	if registry.has_signal("enemy_unregistered") and not registry.enemy_unregistered.is_connected(_on_enemy_unregistered):
		registry.enemy_unregistered.connect(_on_enemy_unregistered)

func _disconnect_enemy_registry() -> void:
	var registry := _get_enemy_registry()
	if registry == null:
		return
	if registry.has_signal("enemy_registered") and registry.enemy_registered.is_connected(_on_enemy_registered):
		registry.enemy_registered.disconnect(_on_enemy_registered)
	if registry.has_signal("enemy_unregistered") and registry.enemy_unregistered.is_connected(_on_enemy_unregistered):
		registry.enemy_unregistered.disconnect(_on_enemy_unregistered)

func _get_enemy_registry() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EnemyRegistry")

func _refresh_tracked_enemies() -> void:
	var registry := _get_enemy_registry()
	if registry != null and registry.has_method("get_enemies"):
		var enemies: Variant = registry.call("get_enemies")
		if enemies is Array:
			for enemy_ref in enemies:
				_track_enemy(enemy_ref as BaseEnemy)
	_prune_tracked_enemies()

func _track_enemy(enemy: BaseEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	if _enemy_death_callbacks.has(enemy_id):
		return
	var callback := Callable(self, "_on_tracked_enemy_death").bind(enemy)
	if not enemy.is_connected("enemy_death", callback):
		enemy.connect("enemy_death", callback)
	_enemy_death_callbacks[enemy_id] = {
		"enemy": weakref(enemy),
		"callback": callback,
	}

func _untrack_enemy(enemy: BaseEnemy) -> void:
	if enemy == null:
		return
	var enemy_id := enemy.get_instance_id()
	if not _enemy_death_callbacks.has(enemy_id):
		return
	var entry: Dictionary = _enemy_death_callbacks[enemy_id]
	var callback := entry.get("callback") as Callable
	if is_instance_valid(enemy) and enemy.is_connected("enemy_death", callback):
		enemy.disconnect("enemy_death", callback)
	_enemy_death_callbacks.erase(enemy_id)

func _clear_tracked_enemies() -> void:
	for enemy_id in _enemy_death_callbacks.keys().duplicate():
		var entry: Dictionary = _enemy_death_callbacks[enemy_id]
		var enemy_ref := entry.get("enemy") as WeakRef
		var enemy := enemy_ref.get_ref() as BaseEnemy if enemy_ref != null else null
		if enemy != null and is_instance_valid(enemy):
			var callback := entry.get("callback") as Callable
			if enemy.is_connected("enemy_death", callback):
				enemy.disconnect("enemy_death", callback)
		_enemy_death_callbacks.erase(enemy_id)

func _prune_tracked_enemies() -> void:
	for enemy_id in _enemy_death_callbacks.keys().duplicate():
		var entry: Dictionary = _enemy_death_callbacks[enemy_id]
		var enemy_ref := entry.get("enemy") as WeakRef
		if enemy_ref == null or enemy_ref.get_ref() == null:
			_enemy_death_callbacks.erase(enemy_id)

func _on_enemy_registered(enemy: Node2D) -> void:
	_track_enemy(enemy as BaseEnemy)

func _on_enemy_unregistered(enemy: Node2D) -> void:
	_untrack_enemy(enemy as BaseEnemy)

func _on_tracked_enemy_death(was_killed: bool, enemy: BaseEnemy) -> void:
	if not was_killed:
		return
	if not _is_active_phase():
		return
	if not _is_objective_active():
		return
	_count_enemy_kill(enemy)

func _on_debug_tick() -> void:
	if _cell == null:
		return
	if not _cell.has_player_inside():
		return
	var snapshot := "kills=%d/%d" % [_kill_count, required_kill_count]
	if _completed:
		snapshot += " completed=true"
	if snapshot == _last_debug_snapshot:
		return
	_last_debug_snapshot = snapshot
	print("[CellObjective][PROGRESS] cell=%s state=%s type=KILL_X_IN_CELL %s" % [_cell.name, _cell_state_name(_cell.state), snapshot])

func _on_debug_completed(reward_type: int) -> void:
	print("[CellObjective][DONE] cell=%s state=%s objective=KILL_X_IN_CELL reward=%s" % [_cell.name, _cell_state_name(_cell.state), _reward_name(reward_type)])

func _reward_name(value: int) -> String:
	match value:
		Cell.RewardType.COMBAT:
			return "COMBAT"
		Cell.RewardType.ECONOMY:
			return "ECONOMY"
		_:
			return "NONE"

func _cell_state_name(value: int) -> String:
	match value:
		Cell.CellState.IDLE:
			return "IDLE"
		Cell.CellState.PLAYER:
			return "PLAYER"
		Cell.CellState.CONTESTED:
			return "CONTESTED"
		Cell.CellState.LOCKED:
			return "LOCKED"
		_:
			return "UNKNOWN"
