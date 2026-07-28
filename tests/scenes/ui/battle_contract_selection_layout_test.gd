extends Node

const PANEL_SCENE := preload("res://UI/scenes/battle_contract_selection_panel.tscn")
const PANEL_SCRIPT := preload("res://UI/scripts/battle_contract_selection_panel.gd")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")
const REWARD := preload("res://data/battle_contracts/reward.tres")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false
var _panel: Control

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LocalizationManager.set_locale("en", false)
	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)
	_panel.call("open", [ELIMINATION, SURVIVAL, REWARD], Callable(), Callable())
	await get_tree().create_timer(0.7, true, false, true).timeout
	await get_tree().process_frame

	var panel_container := _panel.get_node("Shade/Panel") as PanelContainer
	var viewport_rect := _panel.get_viewport_rect()
	var panel_rect := panel_container.get_global_rect()
	_assert_true(
		panel_rect.position.x >= 15.5
			and panel_rect.end.x <= viewport_rect.size.x - 15.5
			and panel_rect.position.y >= 7.5
			and panel_rect.end.y <= viewport_rect.size.y - 7.5,
		"Expanded panel should remain inside viewport safe margins."
	)
	var content := _panel.get_node("Shade/Panel/Margin/Content") as VBoxContainer
	_assert_true(
		content.get_global_rect().end.y <= panel_rect.end.y,
		"Expanded panel content should not overflow below its frame."
	)
	for child: Node in panel_container.get_children():
		_assert_true(
			not (child is ColorRect),
			"PanelContainer should not stretch decorative ColorRects over the full panel."
		)

	var reward_card := _panel.get_node(
		"Shade/Panel/Margin/Content/ExtraContracts/CardRight"
	) as Button
	reward_card.call("set_selected", true, false)
	await get_tree().process_frame
	var rare_badge := reward_card.get_node("Margin/Content/Header/RareBadge") as Label
	var selected_badge := reward_card.get_node("Margin/Content/Header/SelectedBadge") as Label
	_assert_true(
		not rare_badge.get_global_rect().intersects(selected_badge.get_global_rect()),
		"Rare and selected badges should not overlap."
	)
	_assert_true(
		selected_badge.get_parent() == rare_badge.get_parent(),
		"Selected badge should participate in the header container layout."
	)

	var title := reward_card.get_node("Margin/Content/Title") as Label
	_assert_true(
		title.autowrap_mode != TextServer.AUTOWRAP_OFF and title.max_lines_visible == 2,
		"Contract titles should wrap to at most two lines."
	)
	var main_card := _panel.get_node("Shade/Panel/Margin/Content/MainCards/CardLeft") as Button
	var confirm_button := _panel.get_node("Shade/Panel/Margin/Content/Actions/Confirm") as Button
	_assert_true(
		main_card.custom_minimum_size.y >= 240.0,
		"Main contract cards should reserve enough height for wrapped copy."
	)
	_assert_true(
		confirm_button.custom_minimum_size.x >= 230.0,
		"Confirm button should reserve enough width for its English label."
	)

	var narrow_size: Vector2 = PANEL_SCRIPT.calculate_panel_size(Vector2(720.0, 720.0), true)
	_assert_true(
		narrow_size.is_equal_approx(Vector2(688.0, 704.0)),
		"Panel sizing should preserve horizontal and vertical safe margins on narrow viewports."
	)

	_panel.queue_free()
	await get_tree().process_frame
	LocalizationManager.set_locale("zh_CN", false)
	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)
	_panel.call("open", [ELIMINATION, SURVIVAL, REWARD], Callable(), Callable())
	await get_tree().create_timer(0.7, true, false, true).timeout
	reward_card = _panel.get_node(
		"Shade/Panel/Margin/Content/ExtraContracts/CardRight"
	) as Button
	reward_card.call("set_selected", true, false)
	selected_badge = reward_card.get_node("Margin/Content/Header/SelectedBadge") as Label
	await get_tree().process_frame
	_assert_true(
		selected_badge.text == "✓ 已选择",
		"Selected badge should localize to Chinese."
	)
	_assert_true(
		_panel.get_node("Shade/Panel/Margin/Content/TerminalStatus").text.contains("战术链路"),
		"Terminal status should localize instead of remaining English."
	)

	print("FAIL: battle contract selection layout" if _failed else "PASS: battle contract selection layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _reset_runtime_state() -> void:
	LocalizationManager.set_locale("en", false)
	BattleContractManager.reset_runtime_state()
	_panel = null

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
