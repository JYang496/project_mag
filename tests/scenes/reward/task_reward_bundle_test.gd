extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

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
	for typed_reward in [task_bundle[0], effect_reward]:
		var typed_model: Variant = panel.call("_build_reward_card_model", typed_reward)
		assert(str(typed_model.behavior_summary).strip_edges() != "")
		assert(typed_model.primary_chips().size() <= 3)
		assert(str(typed_model.synergy_label).strip_edges() == "")
		assert(str(typed_model.full_detail).strip_edges() != "")
	assert(panel.open_for_summary(summary))
	assert(panel.options_box is GridContainer)
	assert(panel.options_box.get_child_count() == 2)
	assert(not panel.confirm_button.disabled)
	assert(panel.get_node_or_null("Panel/VBox/DetailPanel") == null)
	assert(panel.get_node_or_null("Panel/VBox/ActionPanel/Margin/Actions/ConfirmButton") == panel.confirm_button)
	panel.close_panel()
	assert(panel.open_for_rewards("", [task_bundle[0], task_bundle[1], effect_reward], Callable(), Callable(), false))
	await get_tree().process_frame
	assert(panel.title_label.text == LocalizationManager.tr_key("ui.reward.title", "Choose Reward"))
	assert(panel.panel.size.x >= 999.0 and panel.panel.size.y >= 619.0)
	assert(panel.options_box.columns == 3)
	assert(panel.options_scroll.custom_minimum_size.y >= 400.0)
	assert(panel.get_node_or_null("Panel/VBox/DetailPanel") == null)
	var action_panel := panel.get_node("Panel/VBox/ActionPanel") as Control
	assert(action_panel.custom_minimum_size.y <= 64.0)
	assert(panel.options_scroll.size.y >= action_panel.size.y * 5.0)
	var actions := panel.get_node("Panel/VBox/ActionPanel/Margin/Actions") as HBoxContainer
	var confirm_center_x := panel.confirm_button.position.x + panel.confirm_button.size.x * 0.5
	assert(is_equal_approx(confirm_center_x, actions.size.x * 0.5))
	for index in range(3):
		var reward_button := panel.options_box.get_child(index) as Button
		assert(reward_button != null)
		var key_badge := reward_button.find_child("KeyBadge", true, false) as Label
		assert(key_badge != null and key_badge.text == str(index + 1))
		assert(reward_button.custom_minimum_size.y >= 290.0)
		var summary_label := reward_button.find_child("BehaviorSummary", true, false) as Label
		var comparison_box := reward_button.find_child("ComparisonBox", true, false) as VBoxContainer
		assert(summary_label != null and comparison_box != null)
		assert(comparison_box.get_child_count() <= 3)
		var synergy_status := reward_button.find_child("SynergyStatusLabel", true, false) as Label
		assert(synergy_status == null)
	panel.call("_on_reward_button_pressed", 1, panel.options_box.get_child(1) as Button)
	assert(panel.confirm_button.text == LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward"))
	panel.call("_begin_quick_select_hold", 0)
	panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS * 0.4)
	var previous_progress := (panel.options_box.get_child(0) as Button).find_child("HoldProgress", true, false) as ProgressBar
	assert(previous_progress != null and previous_progress.visible and previous_progress.value > 0.0)
	panel.call("_begin_quick_select_hold", 1)
	assert(panel.get("_selected_index") == 1)
	var held_progress := (panel.options_box.get_child(1) as Button).find_child("HoldProgress", true, false) as ProgressBar
	assert(previous_progress.visible and is_zero_approx(previous_progress.value))
	assert(held_progress != null and held_progress.visible and is_zero_approx(held_progress.value))
	assert(panel.get("_held_quick_select_index") == 1)
	panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS - 0.05)
	assert(panel.visible)
	assert(held_progress.value > 0.8 and held_progress.value < 1.0)
	panel.call("_cancel_quick_select_hold")
	assert(panel.visible)
	assert(held_progress.visible and is_zero_approx(held_progress.value))
	panel.call("_begin_quick_select_hold", 1)
	panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS)
	assert(not panel.visible)
	assert(panel.open_for_rewards("", [task_bundle[0], task_bundle[1], effect_reward], Callable(), Callable(), false))
	for index in range(3):
		var reward_button := panel.options_box.get_child(index) as Button
		var key_badge := reward_button.find_child("KeyBadge", true, false) as Label
		assert(key_badge != null and key_badge.text == str(index + 1))
	panel.call("_begin_quick_select_hold", 2)
	panel.call("_process", RewardSelectionPanel.QUICK_SELECT_HOLD_SECONDS)
	assert(not panel.visible)

	print("PASS: task reward bundles generate, grant once, merge, and preserve repeated hold selection")
	TaskRewardManager.reset_runtime_state(false)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)

func _reset_runtime_state() -> void:
	TaskRewardManager.reset_runtime_state(false)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
