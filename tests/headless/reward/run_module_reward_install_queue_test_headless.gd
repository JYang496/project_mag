extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const REWARD_MANAGER_SCRIPT := preload("res://World/rewards/reward_manager.gd")
const MODULE_PATHS := [
	"res://Player/Weapons/Modules/wmod_damage_up_stat.tscn",
	"res://Player/Weapons/Modules/wmod_bullet_size_stat.tscn",
]

var _ui: UI
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	DataHandler.prepare_world_data()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PlayerData.player = _PlayerStub.new()
	add_child(PlayerData.player)

	var weapon := _instantiate_first_weapon()
	if weapon == null:
		await _fail("missing weapon fixture")
		return
	PlayerData.player_weapon_list.append(weapon)
	add_child(weapon)

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var summary := RewardInfo.new()
	summary.reward_kind = RewardInfo.KIND_ECONOMY
	summary.gold_value = 1
	if not _ui.request_task_reward_summary([summary], Callable()):
		await _fail("failed to open blocking reward summary")
		return

	var reward_manager := REWARD_MANAGER_SCRIPT.new() as BonusManager
	add_child(reward_manager)
	for module_path in MODULE_PATHS:
		var scene := load(module_path) as PackedScene
		var reward := RewardInfo.new()
		reward.module_scene = scene
		reward.module_level = 1
		if scene == null or not reward_manager.grant_reward_immediately(reward):
			await _fail("reward grant failed for %s" % module_path)
			return
	if InventoryData.temporary_modules.size() != MODULE_PATHS.size():
		await _fail("module rewards were not synchronized into temporary inventory")
		return
	for module_instance in InventoryData.temporary_modules:
		if not InventoryData.can_assign_module_to_any_equipped_weapon(module_instance, true):
			await _fail("fixture module is not compatible with current weapon")
			return

	await get_tree().process_frame
	await get_tree().process_frame
	if _ui.module_equip_selection_panel != null and _ui.module_equip_selection_panel.visible:
		await _fail("module install opened over reward summary")
		return

	_ui.reward_selection_panel.call("_on_confirm_pressed")
	for _frame in range(4):
		await get_tree().process_frame
	var panel := _ui.module_equip_selection_panel
	if panel == null or not panel.visible:
		await _fail("queued module install did not open after reward summary")
		return
	if panel._module_instances.size() != MODULE_PATHS.size():
		await _fail("queued modules were not merged into one install session")
		return
	if panel.progress_label.text.strip_edges() != "1 / 2":
		await _fail("batch progress is not visible")
		return

	var first_module := panel._module_instance
	panel.call("_on_slot_selected", weapon)
	if not panel.visible or panel.progress_label.text.strip_edges() != "2 / 2":
		await _fail("installing one module did not advance inside the same panel")
		return
	if first_module == null or first_module.get_parent() != weapon.modules:
		await _fail("installed module was not synchronized to the weapon")
		return

	panel.call("_on_cancel_pressed")
	await get_tree().process_frame
	if not panel.visible or not panel.reward_cancel_dialog.visible:
		await _fail("reward-stage cancel must request confirmation before keeping modules in storage")
		return
	if not InventoryData.temporary_modules.has(panel._module_instance):
		await _fail("cancel confirmation must not remove the pending module from temporary storage")
		return
	panel.call("_on_reward_cancel_confirmed")
	for _frame in range(4):
		await get_tree().process_frame
	if not InventoryData.pending_transactions.is_empty():
		await _fail("module assignment transactions leaked after batch completion")
		return

	print("ModuleRewardInstallQueueTest: PASS")
	await _finish(0)

func _instantiate_first_weapon() -> Weapon:
	for weapon_id in DataHandler.get_weapon_ids():
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if definition != null and definition.scene != null:
			return definition.scene.instantiate() as Weapon
	return null

func _fail(message: String) -> void:
	push_error("ModuleRewardInstallQueueTest: %s" % message)
	await _finish(1)

func _finish(exit_code: int) -> void:
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime_state)

func _reset_runtime_state() -> void:
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()

class _PlayerStub:
	extends Node

	var active_skill_holder := Node.new()

	func create_weapon(_weapon_or_id: Variant) -> void:
		pass

	func predict_auto_fuse_weapon_obtain(_weapon_id: String) -> Dictionary:
		return {"result": "not_applicable"}

	func try_auto_fuse_weapon_obtain(_weapon_id: String) -> Dictionary:
		return {"result": "not_applicable"}
