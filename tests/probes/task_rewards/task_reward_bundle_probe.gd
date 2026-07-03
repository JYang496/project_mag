extends Node

func _ready() -> void:
	assert(bool(CellEffectRuntime.prepare_definitions(true).get("ok", false)))
	assert(bool(CellTaskModuleRuntime.prepare_definitions(true).get("ok", false)))
	TaskRewardManager.reset_runtime_state(false)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()

	var economy := EconomyConfig.new()
	GlobalVariables.economy_data = economy
	var legacy_file := FileAccess.open("user://task_reward_state.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({
		"reward_unlocked": true,
		"pending_level": 0,
		"pending_reward_count": 2,
		"options": [],
	}))
	legacy_file.close()
	TaskRewardManager.call("_load_state")
	assert(int(TaskRewardManager.get("_unbuilt_bundle_count")) == 2)
	TaskRewardManager.call("_build_pending_reward_bundles")
	assert((TaskRewardManager.get("_pending_reward_entries") as Array).size() == 4)
	TaskRewardManager.reset_runtime_state(false)

	economy.task_reward_secondary_task_module_chance = 1.0
	var task_bundle := TaskRewardManager.call("_build_task_reward_bundle", 0) as Array
	assert(task_bundle.size() == 2)
	assert((task_bundle[0] as RewardInfo).reward_kind == RewardInfo.KIND_TASK_MODULE)
	assert((task_bundle[1] as RewardInfo).reward_kind == RewardInfo.KIND_TASK_MODULE)

	economy.task_reward_secondary_task_module_chance = 0.0
	var mixed_bundle := TaskRewardManager.call("_build_task_reward_bundle", 0) as Array
	assert(mixed_bundle.size() == 2)
	assert((mixed_bundle[0] as RewardInfo).reward_kind == RewardInfo.KIND_TASK_MODULE)
	assert((mixed_bundle[1] as RewardInfo).reward_kind == RewardInfo.KIND_CELL_EFFECT)

	var task_reward := task_bundle[0] as RewardInfo
	assert(bool(CellTaskModuleRuntime.grant_module_once("probe_task", task_reward.task_module_id).get("ok", false)))
	assert(bool(CellTaskModuleRuntime.grant_module_once("probe_task", task_reward.task_module_id).get("ok", false)))
	assert(CellTaskModuleRuntime.get_inventory_size() == 1)

	var effect_reward := mixed_bundle[1] as RewardInfo
	assert(CellEffectRuntime.grant_effect_once("probe_effect", effect_reward.cell_effect_id))
	assert(CellEffectRuntime.grant_effect_once("probe_effect", effect_reward.cell_effect_id))
	assert(CellEffectRuntime.get_owned_count(effect_reward.cell_effect_id) == 1)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()

	var entries: Array[Dictionary] = [
		{"id": "summary_1", "status": "pending", "reward": task_bundle[0]},
		{"id": "summary_2", "status": "pending", "reward": task_bundle[0]},
		{"id": "summary_3", "status": "pending", "reward": effect_reward},
	]
	TaskRewardManager.set("_pending_reward_entries", entries)
	assert(str(TaskRewardManager.call("_settle_pending_reward_entries")) == "granted")
	assert(CellTaskModuleRuntime.get_inventory_size() == 2)
	assert(CellEffectRuntime.get_owned_count(effect_reward.cell_effect_id) == 1)
	for entry in entries:
		entry["status"] = "pending"
	TaskRewardManager.set("_pending_reward_entries", entries)
	assert(str(TaskRewardManager.call("_settle_pending_reward_entries")) == "granted")
	assert(CellTaskModuleRuntime.get_inventory_size() == 2)
	assert(CellEffectRuntime.get_owned_count(effect_reward.cell_effect_id) == 1)
	var summary := TaskRewardManager.call("_build_summary_rewards") as Array
	assert(summary.size() == 2)
	assert(int((summary[0] as RewardInfo).get_meta("summary_count", 1)) == 2)

	var panel := preload("res://UI/scenes/reward_selection_panel.tscn").instantiate() as RewardSelectionPanel
	add_child(panel)
	await get_tree().process_frame
	assert(panel.open_for_summary(summary))
	assert(panel.options_box is GridContainer)
	assert(panel.options_box.get_child_count() == 2)
	assert(not panel.confirm_button.disabled)
	var pinned_title := panel.detail_title_label.text
	panel.call("_on_reward_hover_entered", 1)
	assert(panel.detail_title_label.text != pinned_title)
	panel.call("_on_reward_hover_exited", 1)
	assert(panel.detail_title_label.text == pinned_title)

	print("PASS: task reward bundles generate, grant once, merge, and open in summary mode")
	TaskRewardManager.reset_runtime_state(false)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	get_tree().quit()
