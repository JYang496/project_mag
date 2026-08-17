extends Node

const PANEL_SCENE := preload("res://UI/scenes/battle_contract_selection_panel.tscn")
const PANEL_SCRIPT := preload("res://UI/scripts/battle_contract_selection_panel.gd")
const ELIMINATION := preload("res://data/battle_contracts/elimination.tres")
const SURVIVAL := preload("res://data/battle_contracts/survival.tres")
const OPERATION := preload("res://data/battle_contracts/operation.tres")
const CONTAINMENT := preload("res://data/battle_contracts/containment.tres")
const EXTRACTION := preload("res://data/battle_contracts/extraction.tres")
const REWARD := preload("res://data/battle_contracts/reward.tres")
const REST := preload("res://data/battle_contracts/rest.tres")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false
var _panel: Control
var _confirm_count := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	LocalizationManager.set_locale("en", false)
	_assert_true(
		LocalizationManager.tr_key(REST.name_key, "") == "Rest Protocol",
		"Rest Protocol name should be present in the English translation resource."
	)
	_assert_true(
		LocalizationManager.tr_key("battle_contract.card.rest.summary", "")
			== "Enter the rest area and unlock full loadout management.",
		"Rest Protocol summary should be present in the English translation resource."
	)
	_panel = PANEL_SCENE.instantiate() as Control
	add_child(_panel)
	_panel.call("open", [ELIMINATION, SURVIVAL, REWARD], Callable(self, "_on_contract_confirmed"), Callable())
	await get_tree().process_frame
	for opening_card: Button in _panel.get("cards") as Array:
		var opening_icon := opening_card.get_node("Margin/Content/Header/ContractIcon") as Control
		var drawn_center_global := opening_card.get_global_transform_with_canvas() \
			* (opening_card.call("get_contract_icon_center_local") as Vector2)
		_assert_true(
			opening_icon.get_global_rect().has_point(drawn_center_global),
			"Protocol icon should remain in its slot during the first opening frame."
		)
	await get_tree().create_timer(1.0, true, false, true).timeout
	await get_tree().process_frame
	if bool(_panel.get("_locked")):
		_panel.call("_kill_transition")
		_panel.call("_finish_open_transition")

	var panel_container := _panel.get_node("Shade/Panel") as PanelContainer
	var shade := _panel.get_node("Shade") as ColorRect
	var viewport_rect := _panel.get_viewport_rect()
	var panel_rect := panel_container.get_global_rect()
	_assert_true(
		_panel.z_index >= 200,
		"Contract selection should render above persistent HUD docks."
	)
	_assert_true(
		PANEL_SCRIPT.SHADE_OPACITY >= 0.74 and shade.color.a > 0.58,
		"Contract selection should target a strong shade and exceed the old weak opacity during reveal."
	)
	_assert_true(
		not _panel.get_node("Shade/Panel/Margin/Content/TerminalStatus").visible,
		"Decorative terminal status should not consume scarce vertical space."
	)
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
	var selection_mark := reward_card.get_node("Margin/Content/Header/SelectionMark") as Label
	_assert_true(
		not rare_badge.get_global_rect().intersects(selected_badge.get_global_rect()),
		"Rare and selected badges should not overlap."
	)
	_assert_true(
		selection_mark.text == "●",
		"Selected cards should expose a persistent filled selection mark."
	)
	_assert_true(
		not selected_badge.get_global_rect().intersects(selection_mark.get_global_rect()),
		"Selected text and its selection mark should have real geometric separation."
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
	var protocol_cards: Array = _panel.get("cards") as Array
	var interaction_hint := _panel.get_node("Shade/Panel/Margin/Content/Subtitle") as Label
	var settled_icon_centers: Array[Vector2] = []
	for protocol_card: Button in protocol_cards:
		settled_icon_centers.append(protocol_card.call("get_contract_icon_center_local") as Vector2)
	panel_container.scale.x = 0.025
	await get_tree().process_frame
	for index in range(3):
		_assert_true(
			(protocol_cards[index].call("get_contract_icon_center_local") as Vector2).is_equal_approx(
				settled_icon_centers[index]
			),
			"Protocol card %d icon placement should ignore the panel's opening scale." % (index + 1)
		)
	panel_container.scale.x = 1.0
	await get_tree().process_frame
	_assert_true(
		interaction_hint.text.contains("Hold") and interaction_hint.text.contains("1–3"),
		"Protocol selection should explicitly teach both card hold and numeric hold shortcuts."
	)
	for index in range(3):
		var protocol_card := protocol_cards[index] as Button
		var key_badge := protocol_card.get_node("Margin/Content/Header/KeyBadge") as Label
		var contract_icon := protocol_card.get_node("Margin/Content/Header/ContractIcon") as Control
		_assert_true(key_badge.visible and key_badge.text == str(index + 1), "Protocol card %d should expose its numeric quick-select key." % (index + 1))
		_assert_true(
			not key_badge.get_global_rect().intersects(contract_icon.get_global_rect()),
			"Protocol card %d numeric shortcut should not overlap its protocol icon slot." % (index + 1)
		)
		_assert_true(
			contract_icon.get_global_rect().has_point(
				protocol_card.get_global_rect().position + protocol_card.call("get_contract_icon_center_local")
			),
			"Protocol card %d should draw its icon inside the dedicated icon slot." % (index + 1)
		)
	_assert_true(int(_panel.call("_quick_select_index_for_key", KEY_1)) == 0, "Number key 1 should map to the first protocol card.")
	_assert_true(int(_panel.call("_quick_select_index_for_key", KEY_KP_2)) == 1, "Numpad 2 should map to the second protocol card.")
	_assert_true(int(_panel.call("_quick_select_index_for_key", KEY_3)) == 2, "Number key 3 should map to the third protocol card.")
	for card: Button in _panel.cards:
		if not card.visible:
			continue
		var card_content := card.get_node("Margin/Content") as VBoxContainer
		_assert_true(
			card_content.get_global_rect().end.y <= card.get_global_rect().end.y + 0.5,
			"Contract card %s content should remain inside its reduced card height (%.1f <= %.1f)." % [
				card.name,
				card_content.get_global_rect().end.y,
				card.get_global_rect().end.y,
			]
		)
	_assert_true(
		main_card.custom_minimum_size.y >= 222.0,
		"Main contract cards should reserve enough height for wrapped copy without dominating the viewport."
	)
	_assert_true(
		reward_card.custom_minimum_size.y < main_card.custom_minimum_size.y,
		"The rare reward card should remain visually secondary to the main decision cards."
	)
	_assert_true(
		confirm_button.custom_minimum_size.x >= 230.0,
		"Confirm button should reserve enough width for its English label."
	)

	_panel.call("_begin_card_hold", main_card)
	_panel.call("_process", PANEL_SCRIPT.CARD_HOLD_SECONDS * 0.5)
	var hold_progress := main_card.get_node("HoldProgress") as ProgressBar
	_assert_true(
		hold_progress.visible and hold_progress.value > 0.45 and hold_progress.value < 0.55,
		"Holding a contract card should expose determinate confirmation progress (visible=%s value=%.2f index=%d locked=%s)." % [
			hold_progress.visible,
			hold_progress.value,
			int(_panel.get("_held_card_index")),
			bool(_panel.get("_locked")),
		]
	)
	_panel.call("_cancel_card_hold")
	_assert_true(
		not hold_progress.visible and is_zero_approx(hold_progress.value) and _confirm_count == 0,
		"Releasing a contract card early should cancel confirmation and clear its progress."
	)
	_panel.call("_begin_card_hold_by_index", 1)
	_panel.call("_process", PANEL_SCRIPT.CARD_HOLD_SECONDS * 0.5)
	var keyboard_hold_progress := (protocol_cards[1] as Button).get_node("HoldProgress") as ProgressBar
	_assert_true(
		keyboard_hold_progress.visible and keyboard_hold_progress.value > 0.45 and keyboard_hold_progress.value < 0.55,
		"Holding numeric key 2 should drive the matching protocol card progress."
	)
	_panel.call("_cancel_card_hold")
	_assert_true(
		not keyboard_hold_progress.visible and _confirm_count == 0,
		"Releasing a numeric quick-select key early should cancel confirmation."
	)
	_panel.call("_begin_card_hold", main_card)
	confirm_button.disabled = false # The layout test runs outside the protocol-selection phase.
	_panel.call("_process", PANEL_SCRIPT.CARD_HOLD_SECONDS)
	_assert_true(
		_confirm_count == 1 and bool(_panel.get("_locked")),
		"Holding a contract card through the threshold should select and confirm it exactly once (count=%d index=%d locked=%s)." % [
			_confirm_count,
			int(_panel.get("_held_card_index")),
			bool(_panel.get("_locked")),
		]
	)

	var narrow_size: Vector2 = PANEL_SCRIPT.calculate_panel_size(Vector2(720.0, 720.0), true)
	_assert_true(
		narrow_size.is_equal_approx(Vector2(688.0, 672.0)),
		"Panel sizing should preserve horizontal and vertical safe margins on narrow viewports."
	)

	_panel.queue_free()
	await get_tree().process_frame
	LocalizationManager.set_locale("zh_CN", false)
	_assert_true(
		LocalizationManager.tr_key(REST.name_key, "") == "休息协议",
		"Rest Protocol name should be present in the Chinese translation resource."
	)
	_assert_true(
		LocalizationManager.tr_key("battle_contract.card.rest.summary", "")
			== "进入休息区并开放完整构筑管理。",
		"Rest Protocol summary should be present in the Chinese translation resource."
	)
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
	interaction_hint = _panel.get_node("Shade/Panel/Margin/Content/Subtitle") as Label
	_assert_true(
		interaction_hint.text.contains("长按") and interaction_hint.text.contains("1–3"),
		"Chinese protocol selection should explain the hold interaction and numeric shortcuts."
	)
	_assert_true(
		selected_badge.text == "✓ 已选择",
		"Selected badge should localize to Chinese."
	)
	_assert_true(
		_panel.get_node("Shade/Panel/Margin/Content/TerminalStatus").text.contains("战术链路"),
		"Terminal status should localize instead of remaining English."
	)
	_assert_reward_copy(ELIMINATION, "正常")
	_assert_reward_copy(SURVIVAL, "正常")
	_assert_reward_copy(OPERATION, "正常")
	_assert_reward_copy(CONTAINMENT, "较多")
	_assert_reward_copy(EXTRACTION, "正常")
	_assert_reward_copy(REWARD, "大量")

	print("FAIL: battle contract selection layout" if _failed else "PASS: battle contract selection layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _reset_runtime_state() -> void:
	LocalizationManager.set_locale("en", false)
	BattleContractManager.reset_runtime_state()
	_panel = null

func _on_contract_confirmed() -> void:
	_confirm_count += 1

func _assert_reward_copy(definition: Resource, expected_gold_tier: String) -> void:
	var card := preload("res://UI/scenes/battle_contract_card.tscn").instantiate() as Button
	add_child(card)
	card.call("setup", definition)
	var reward_label: Label
	if str(definition.contract_id) == "reward":
		reward_label = card.get_node("Margin/Content/RewardDetails/Reward") as Label
	else:
		reward_label = card.get_node("Margin/Content/InfoGrid/Reward") as Label
	_assert_true(
		reward_label.text.contains("金币：%s" % expected_gold_tier),
		"Contract %s should expose its relative gold tier." % str(definition.contract_id)
	)
	_assert_true(
		reward_label.text.contains("额外：随机装备选项"),
		"Contract %s should disclose the random post-battle item draft." % str(definition.contract_id)
	)
	card.queue_free()

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
