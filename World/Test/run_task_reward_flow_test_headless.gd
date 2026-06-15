extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	RunRouteManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	DataHandler.prepare_world_data()

	var reward_manager := BonusManager.new()
	reward_manager.name = "RewardManager"
	add_child(reward_manager)

	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("TestCell")
	if not TaskRewardManager.has_pending_reward():
		_fail(1, "TaskRewardFlowTest: objective did not unlock a reward.")
		return
	var first_options := TaskRewardManager.get_pending_reward_options()
	if first_options.size() != 3:
		_fail(2, "TaskRewardFlowTest: objective reward did not contain three options.")
		return
	TaskRewardManager.notify_objective_completed("SecondCell")
	if TaskRewardManager.get_pending_reward_options().size() != 3:
		_fail(3, "TaskRewardFlowTest: repeated objective completion changed reward count.")
		return

	PhaseManager.enter_gameover()
	if TaskRewardManager.has_pending_reward():
		_fail(4, "TaskRewardFlowTest: failed battle retained the reward.")
		return

	PhaseManager.reset_runtime_state()
	PhaseManager.enter_battle()
	PhaseManager.current_level += 1
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	if TaskRewardManager.has_pending_reward():
		_fail(5, "TaskRewardFlowTest: normal battle completion granted a default reward.")
		return

	for route in RunRouteManager.get_available_routes_for_level(0):
		if route != null and not route.battle_enabled:
			_fail(6, "TaskRewardFlowTest: non-battle route remains player-selectable.")
			return

	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 211
	if not TaskRewardManager.begin_battle_snapshot():
		_fail(7, "TaskRewardFlowTest: failed to create pending-reward snapshot.")
		return
	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("PersistentCell")
	PhaseManager.current_level += 1
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	if not TaskRewardManager.prepare_world_start():
		_fail(8, "TaskRewardFlowTest: pending reward was not detected on restart.")
		return
	PlayerData.player_gold = 1
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(true)
	if not TaskRewardManager.restore_snapshot_after_player_spawn():
		_fail(9, "TaskRewardFlowTest: pending-reward rest state was not restored.")
		return
	if not TaskRewardManager.has_pending_reward() or int(PlayerData.player_gold) != 211:
		_fail(10, "TaskRewardFlowTest: pending reward state was not preserved.")
		return

	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 137
	if not TaskRewardManager.begin_battle_snapshot():
		_fail(11, "TaskRewardFlowTest: failed to create rollback snapshot.")
		return
	PlayerData.player_gold = 1
	if not TaskRewardManager.prepare_world_start():
		_fail(12, "TaskRewardFlowTest: unfinished battle was not detected on restart.")
		return
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(true)
	if not TaskRewardManager.restore_snapshot_after_player_spawn():
		_fail(13, "TaskRewardFlowTest: rollback snapshot was not restored.")
		return
	if int(PlayerData.player_gold) != 137:
		_fail(14, "TaskRewardFlowTest: player state did not roll back to battle start.")
		return

	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	print("TaskRewardFlowTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
