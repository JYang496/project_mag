extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0

	var cell := (load("res://Board/Cells/cell.tscn") as PackedScene).instantiate() as Cell
	if cell == null:
		_fail("failed to instantiate cell")
		return
	cell.name = "OffenseKillGlobalCountCell"
	add_child(cell)
	await get_tree().process_frame

	cell.set_locked(false)
	cell.logical_id = 5
	cell.objective_enabled = true
	var player := (load("res://Player/Mechas/scripts/Player.gd") as Script).new() as Player
	if player == null:
		_fail("failed to create lightweight Player instance")
		return
	cell.call("_on_area_2d_body_entered", player)

	var module_root := cell.get_node_or_null("Modules")
	if module_root == null:
		_fail("cell did not create Modules root")
		return
	var objective := (load("res://Board/Cells/Modules/cell_obj_offense_kill.tscn") as PackedScene).instantiate() as OffenseKillObjectiveModule
	if objective == null:
		_fail("failed to instantiate offense kill objective")
		return
	module_root.add_child(objective)
	await get_tree().process_frame
	objective.objective_enabled = true
	objective.set_task_parameters({
		"required_kill_count": 2,
		"count_kill_only_when_player_inside": true,
	})

	PhaseManager.enter_battle()
	await get_tree().process_frame

	var enemy := (load("res://Npc/enemy/scenes/base_enemy.tscn") as PackedScene).instantiate() as BaseEnemy
	if enemy == null:
		_fail("failed to instantiate enemy")
		return
	enemy.global_position = Vector2(10000.0, 10000.0)
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame

	var registry_count := int(EnemyRegistry.get_enemy_count()) if EnemyRegistry != null and EnemyRegistry.has_method("get_enemy_count") else -1
	var tracked_count := int((objective.get("_enemy_death_callbacks") as Dictionary).size())
	if registry_count <= 0:
		_fail("test enemy was not registered in EnemyRegistry, count=%d" % registry_count)
		return
	if tracked_count <= 0:
		_fail("offense objective did not track registered enemy deaths, registry_count=%d tracked_count=%d" % [registry_count, tracked_count])
		return

	if cell.get_enemy_count() != 0:
		_fail("test enemy should not be tracked as inside the task cell")
		return
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		_fail("test should be in battle phase before kill, got %s" % str(PhaseManager.current_state()))
		return
	if not cell.has_player_inside():
		_fail("test cell should report player presence before kill")
		return
	if not bool(objective.call("_is_objective_active")):
		_fail("offense objective should be active before kill")
		return

	enemy.enemy_death.emit(true)
	await get_tree().process_frame
	var status := objective.get_combat_task_status()
	if str(status.get("value_text", "")) != "1/2":
		_fail("outside-cell enemy kill should count while player is inside; got %s" % str(status))
		return

	enemy.enemy_death.emit(true)
	await get_tree().process_frame
	status = objective.get_combat_task_status()
	if str(status.get("value_text", "")) != "1/2":
		_fail("same enemy death should not double-count; got %s" % str(status))
		return

	enemy.queue_free()
	cell.queue_free()
	player.free()
	await get_tree().process_frame
	print("OffenseKillObjectiveGlobalCountTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("OffenseKillObjectiveGlobalCountTest: " + message)
	get_tree().quit(1)
