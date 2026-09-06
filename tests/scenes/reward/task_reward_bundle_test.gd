extends Node

const REWARD_PANEL_SCRIPT := preload("res://UI/components/RewardSelectionPanel/RewardSelectionPanel.gd")

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")

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

	var panel := preload("res://UI/components/RewardSelectionPanel/RewardSelectionPanel.tscn").instantiate() as Control
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
	var reward_choices: Array[RewardInfo] = [task_bundle[0], task_bundle[1], effect_reward, effect_reward]
	assert(panel.open_for_rewards("", reward_choices, Callable(), Callable(), false))
	await get_tree().process_frame
	assert(panel.title_label.text == LocalizationManager.tr_key("ui.reward.title", "Choose Reward"))
	assert(panel.panel.size.x >= 999.0 and panel.panel.size.y >= 619.0)
	assert(panel.options_box.columns == 3)
	assert(panel.options_box.get_child_count() == 3)
	assert(panel.options_scroll.custom_minimum_size.y >= 380.0)
	assert(panel.get_node_or_null("Panel/VBox/DetailPanel") == null)
	assert(panel.get_node_or_null("Panel/VBox/SelectedDetail") == null)
	var action_panel := panel.get_node("Panel/VBox/ActionPanel") as Control
	assert(action_panel.custom_minimum_size.y <= 64.0)
	assert(panel.options_scroll.size.y >= action_panel.size.y * 5.0)
	assert(panel.options_scroll.get_global_rect().end.y <= action_panel.get_global_rect().position.y)
	var actions := panel.get_node("Panel/VBox/ActionPanel/Margin/Actions") as HBoxContainer
	var confirm_center_x: float = float(panel.confirm_button.position.x + panel.confirm_button.size.x * 0.5)
	assert(is_equal_approx(confirm_center_x, actions.size.x * 0.5))
	for index in range(3):
		var reward_button := panel.options_box.get_child(index) as Button
		assert(reward_button != null)
		assert(reward_button.tooltip_text == "")
		var key_badge := reward_button.find_child("KeyBadge", true, false) as Label
		assert(key_badge != null and key_badge.text == str(index + 1))
		assert(reward_button.custom_minimum_size.y >= 290.0)
		var summary_label := reward_button.find_child("BehaviorSummary", true, false) as Label
		var comparison_box := reward_button.find_child("ComparisonBox", true, false) as VBoxContainer
		assert(summary_label != null and comparison_box != null)
		assert(comparison_box.get_child_count() <= 3)
		var synergy_status := reward_button.find_child("SynergyStatusLabel", true, false) as Label
		assert(synergy_status == null)
		if index > 0:
			assert((panel.options_box.get_child(index - 1) as Button).focus_neighbor_right != NodePath(""))
	var first_card := panel.options_box.get_child(0) as Button
	assert(get_viewport().gui_get_focus_owner() == first_card)
	var selected_style := first_card.get_theme_stylebox("normal") as StyleBoxFlat
	assert(selected_style.border_color.is_equal_approx(TOKENS.COLOR_ACCENT_SYSTEM))
	assert(selected_style.border_width_left == TOKENS.BORDER_STRONG)
	var first_selection_bar := first_card.find_child("SelectionIndicatorBar", true, false) as ColorRect
	assert(first_selection_bar != null and first_selection_bar.visible)
	assert(first_selection_bar.color.is_equal_approx(TOKENS.COLOR_ACCENT_SYSTEM))
	assert(is_equal_approx(first_selection_bar.offset_bottom - first_selection_bar.offset_top, 4.0))
	var hold_track := first_card.find_child("HoldProgress", true, false) as ProgressBar
	var hold_fill := hold_track.get_theme_stylebox("fill") as StyleBoxFlat
	assert(hold_fill.bg_color.is_equal_approx(TOKENS.COLOR_ACCENT_ACTION))
	var second_card := panel.options_box.get_child(1) as Button
	var unselected_style := second_card.get_theme_stylebox("normal") as StyleBoxFlat
	assert(unselected_style.border_width_left == TOKENS.BORDER_THIN)
	assert(unselected_style.border_color.a <= 0.65)
	var second_selection_bar := second_card.find_child("SelectionIndicatorBar", true, false) as ColorRect
	assert(second_selection_bar != null and not second_selection_bar.visible)
	panel.call("_on_reward_button_pressed", 1, second_card)
	assert(get_viewport().gui_get_focus_owner() == second_card)
	assert(not first_selection_bar.visible and second_selection_bar.visible)
	selected_style = second_card.get_theme_stylebox("normal") as StyleBoxFlat
	assert(selected_style.border_color.is_equal_approx(TOKENS.COLOR_ACCENT_SYSTEM))
	assert(selected_style.border_width_left == TOKENS.BORDER_STRONG)
	var space_press := InputEventKey.new()
	space_press.keycode = KEY_SPACE
	space_press.pressed = true
	assert(bool(panel.call("_is_space_key_event", space_press)))
	panel.call("_input", space_press)
	assert(panel.get("_selected_index") == 1)
	assert(panel.confirm_button.icon is ImageTexture)
	assert(panel.confirm_button.icon.get_size() == Vector2(48, 16))
	assert(panel.visible)
	assert(get_viewport().gui_get_focus_owner() == panel.confirm_button)
	var physical_space_release := InputEventKey.new()
	physical_space_release.physical_keycode = KEY_SPACE
	physical_space_release.pressed = false
	assert(bool(panel.call("_is_space_key_event", physical_space_release)))
	panel.call("_input", physical_space_release)
	assert(panel.visible)
	assert(get_viewport().gui_get_focus_owner() == panel.confirm_button)
	assert(panel.get_node_or_null("Panel/VBox/SelectedDetail") == null)
	panel.call("_input", space_press)
	assert(not panel.visible)
	var quick_select_rewards: Array[RewardInfo] = [task_bundle[0], task_bundle[1], effect_reward]
	assert(panel.open_for_rewards("", quick_select_rewards, Callable(), Callable(), false))
	panel.call("_begin_quick_select_hold", 0)
	panel.call("_process", REWARD_PANEL_SCRIPT.QUICK_SELECT_HOLD_SECONDS * 0.4)
	var previous_progress := (panel.options_box.get_child(0) as Button).find_child("HoldProgress", true, false) as ProgressBar
	assert(previous_progress != null and previous_progress.visible and previous_progress.value > 0.0)
	panel.call("_begin_quick_select_hold", 1)
	assert(panel.get("_selected_index") == 1)
	var held_progress := (panel.options_box.get_child(1) as Button).find_child("HoldProgress", true, false) as ProgressBar
	assert(previous_progress.visible and is_zero_approx(previous_progress.value))
	assert(held_progress != null and held_progress.visible and is_zero_approx(held_progress.value))
	assert(panel.get("_held_quick_select_index") == 1)
	panel.call("_process", REWARD_PANEL_SCRIPT.QUICK_SELECT_HOLD_SECONDS - 0.05)
	assert(panel.visible)
	assert(held_progress.value > 0.8 and held_progress.value < 1.0)
	panel.call("_cancel_quick_select_hold")
	assert(panel.visible)
	assert(held_progress.visible and is_zero_approx(held_progress.value))
	panel.call("_begin_quick_select_hold", 1)
	panel.call("_process", REWARD_PANEL_SCRIPT.QUICK_SELECT_HOLD_SECONDS)
	assert(not panel.visible)
	assert(panel.open_for_rewards("", quick_select_rewards, Callable(), Callable(), false))
	panel.confirm_button.emit_signal("pressed")
	assert(not panel.visible)
	assert(panel.open_for_rewards("", quick_select_rewards, Callable(), Callable(), false))
	for index in range(3):
		var reward_button := panel.options_box.get_child(index) as Button
		var key_badge := reward_button.find_child("KeyBadge", true, false) as Label
		assert(key_badge != null and key_badge.text == str(index + 1))
	panel.call("_begin_quick_select_hold", 2)
	panel.call("_process", REWARD_PANEL_SCRIPT.QUICK_SELECT_HOLD_SECONDS)
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
