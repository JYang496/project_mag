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
		if not opening_card.visible:
			continue
		var opening_icon := opening_card.get_node("Margin/Content/Header/ContractIcon") as Control
		_assert_true(
			(opening_icon.call("get_draw_center_local") as Vector2).is_equal_approx(opening_icon.size * 0.5),
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
		panel_rect.position.x >= 23.5
			and panel_rect.end.x <= viewport_rect.size.x - 23.5
			and panel_rect.position.y >= 15.5
			and panel_rect.end.y <= viewport_rect.size.y - 15.5,
		"Expanded panel should remain inside viewport safe margins."
	)
	var outer_style := panel_container.get_theme_stylebox("panel") as StyleBoxFlat
	_assert_true(
		outer_style != null and outer_style.bg_color.a == 0.0
			and outer_style.border_width_left == 0
			and outer_style.border_width_top == 0
			and outer_style.border_width_right == 0
			and outer_style.border_width_bottom == 0,
		"Outer protocol layout container should remain visually transparent."
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
		"Shade/Panel/Margin/Content/MainCards/CardRight"
	) as Button
	var reward_content := reward_card.get_node("Margin") as MarginContainer
	var unselected_content_rect := reward_content.get_global_rect()
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
	var selection_rail := reward_card.get_node("SelectionRail") as ColorRect
	var selected_style := reward_card.get_theme_stylebox("pressed") as StyleBoxFlat
	_assert_true(
		selection_rail.visible and reward_card.get_node("AccentLine").offset_right == 8.0,
		"Selected cards should use a bottom light rail and a stronger left accent."
	)
	_assert_true(
		selected_style != null and selected_style.border_width_left == 1,
		"Selection should keep a restrained border so it cannot be confused with the enhanced armor frame."
	)
	_assert_true(
		not selected_badge.get_global_rect().intersects(selection_mark.get_global_rect()),
		"Selected text and its selection mark should have real geometric separation."
	)
	_assert_true(
		selected_badge.get_parent() == rare_badge.get_parent(),
		"Selected badge should participate in the header container layout."
	)
	_assert_true(
		reward_content.get_global_rect().is_equal_approx(unselected_content_rect),
		"Selecting a protocol should not resize its content area or reflow wrapped copy."
	)

	var title := reward_card.get_node("Margin/Content/Title") as Label
	_assert_true(
		title.autowrap_mode != TextServer.AUTOWRAP_OFF and title.max_lines_visible == 2,
		"Contract titles should wrap to at most two lines."
	)
	var main_card := _panel.get_node("Shade/Panel/Margin/Content/MainCards/CardLeft") as Button
	var main_info_grid := main_card.get_node("Margin/Content/InfoGrid") as HBoxContainer
	var objective_gap := main_card.get_node("Margin/Content/ObjectiveGap") as Control
	var main_description := main_info_grid.get_node("Description") as Label
	_assert_true(
		main_info_grid.get_child_count() == 1 \
			and main_info_grid.get_child(0).name == "Description" \
			and (main_info_grid.get_child(0) as Control).size_flags_horizontal == Control.SIZE_EXPAND_FILL,
		"Standard protocol cards should devote the full information width to the core objective."
	)
	_assert_true(
		objective_gap.custom_minimum_size.y >= 12.0 \
			and main_description.vertical_alignment == VERTICAL_ALIGNMENT_TOP \
			and main_info_grid.size_flags_vertical != Control.SIZE_EXPAND_FILL \
			and (main_card.get_node("Margin/Content/ContentSpacer") as Control).size_flags_vertical == Control.SIZE_EXPAND_FILL,
		"Core objectives should start directly below the title instead of floating at card center."
	)
	_assert_true(
		reward_card.get_node("Margin/Content/RewardDetails") is VBoxContainer,
		"Reward Protocol should use the same vertical reading order as standard cards."
	)
	_assert_true(
		not reward_card.has_node("Margin/Content/RewardDetails/Reward"),
		"Reward Protocol cards should not repeat protocol reward copy."
	)
	var confirm_button := _panel.get_node("Shade/Panel/Margin/Content/Actions/Confirm") as Button
	var protocol_cards: Array = _panel.get("cards") as Array
	var select_range := _panel.get_node("Shade/Panel/Margin/Content/Subtitle/SelectRange") as Label
	var escape_icon := _panel.get_node("Shade/Panel/Margin/Content/Subtitle/EscapeIcon") as TextureRect
	panel_container.scale.x = 0.025
	await get_tree().process_frame
	for index in range(3):
		var scaled_icon := (protocol_cards[index] as Button).get_node("Margin/Content/Header/ContractIcon") as Control
		_assert_true(
			(scaled_icon.call("get_draw_center_local") as Vector2).is_equal_approx(scaled_icon.size * 0.5),
			"Protocol card %d icon should retain its local drawing center during panel scaling." % (index + 1)
		)
	panel_container.scale.x = 1.0
	await get_tree().process_frame
	_assert_true(
		select_range.text.contains("1–3"),
		"Protocol selection should match its numeric shortcut range to three visible options."
	)
	_assert_true(
		escape_icon.texture != null,
		"Protocol selection should show the Escape keyboard icon instead of a text key name."
	)
	_assert_true(
		confirm_button.icon != null,
		"Protocol confirmation should use the input-prompt icon instead of a text key name."
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
			contract_icon.get_script() != null \
				and (contract_icon.call("get_draw_center_local") as Vector2).is_equal_approx(contract_icon.size * 0.5),
			"Protocol card %d should delegate drawing to its dedicated local icon slot." % (index + 1)
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
		confirm_button.custom_minimum_size.x >= 190.0,
		"Confirm button should reserve enough width for its English label."
	)
	_assert_true(
		not _panel.has_node("Shade/Panel/Margin/Content/MainContractsLabel"),
		"The redundant Main Contracts section label should be removed."
	)
	_panel.call("_select_card_by_index", 1)
	var detail_name := _panel.get_node("Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Header/Name") as Label
	var detail_copy := _panel.get_node("Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/Objective") as Label
	var current_selection := _panel.get_node("Shade/Panel/Margin/Content/Actions/CurrentSelection") as Label
	_assert_true(
		detail_name.text == "Protocol Briefing" \
			and detail_copy.text.contains("BATTLE STRUCTURE") \
			and detail_copy.text.contains("COMPLETION"),
		"Numeric selection should expose a structured briefing without repeating the protocol title."
	)
	_panel.call("_set_current_selection", SURVIVAL)
	_assert_true(
		current_selection.text.contains("Survival Protocol"),
		"The bottom action bar should state which protocol will be confirmed."
	)
	var survival_card := protocol_cards[1] as Button
	survival_card.call("set_enhanced_offer", ["Enemies gain +20% movement speed"], ["Gold +40%"])
	survival_card.call("set_selected", true, false)
	var stable_panel_rect := panel_container.get_global_rect()
	var stable_cards_rect := (_panel.get_node("Shade/Panel/Margin/Content/MainCards") as HBoxContainer).get_global_rect()
	var stable_detail_rect := (_panel.get_node("Shade/Panel/Margin/Content/DetailPanel") as PanelContainer).get_global_rect()
	survival_card.call("set_enhanced_mode", true)
	_panel.call("_on_card_enhanced_mode_changed", true, survival_card)
	await get_tree().process_frame
	_assert_true(
		panel_container.get_global_rect().is_equal_approx(stable_panel_rect) \
			and (_panel.get_node("Shade/Panel/Margin/Content/MainCards") as HBoxContainer).get_global_rect().is_equal_approx(stable_cards_rect) \
			and (_panel.get_node("Shade/Panel/Margin/Content/DetailPanel") as PanelContainer).get_global_rect().is_equal_approx(stable_detail_rect),
		"Enhanced mode should not move the centered panel, card row, or protocol briefing (panel %s -> %s, cards %s -> %s, detail %s -> %s)." % [
			stable_panel_rect, panel_container.get_global_rect(), stable_cards_rect,
			(_panel.get_node("Shade/Panel/Margin/Content/MainCards") as HBoxContainer).get_global_rect(),
			stable_detail_rect, (_panel.get_node("Shade/Panel/Margin/Content/DetailPanel") as PanelContainer).get_global_rect(),
		]
	)
	var enhancement_toggle := survival_card.get_node("EnhancementToggle") as CheckButton
	_assert_true(
		enhancement_toggle.get_global_rect().size.is_equal_approx(Vector2(168.0, 38.0)) \
			and survival_card.get_global_rect().encloses(enhancement_toggle.get_global_rect()) \
			and (survival_card.get_node("EnhancedFrame") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Enhanced interaction should use the visible 168x38 toggle while its decorative frame ignores pointer input."
	)
	_assert_true(
		detail_copy.text.contains("ENHANCED RISK") \
			and detail_copy.text.contains("EXTRA REWARD") \
			and current_selection.text.contains("Enhanced") \
			and confirm_button.text == "Begin Enhanced Protocol",
		"Enhanced selection should synchronize its briefing, current selection, and confirm action."
	)
	var enemy_preview := _panel.get_node("Shade/Panel/Margin/Content/DetailPanel/DetailMargin/DetailContent/Details/EnemyPreview") as VBoxContainer
	var enemy_preview_header := enemy_preview.get_node("Header") as Label
	var enemy_preview_entries := enemy_preview.get_node("Entries") as HBoxContainer
	_assert_true(
		enemy_preview.visible and enemy_preview_entries.get_child_count() > 0,
		"Protocol details should replace reward copy with the next battle's enemy preview."
	)
	var uncertain_snapshot := PANEL_SCRIPT.build_enemy_preview_snapshot("survival", 1) as Dictionary
	_assert_true(
		bool(uncertain_snapshot.get("uncertain", false)) \
			and (uncertain_snapshot.get("entries", []) as Array).size() == 2 \
			and LocalizationManager.tr_key("battle_contract.ui.enemy_preview.possible", "") == "MAY APPEAR",
		"A randomized multi-enemy pool should be labeled as possible rather than confirmed."
	)
	var reward_snapshot := PANEL_SCRIPT.build_enemy_preview_snapshot("reward", 1) as Dictionary
	var reward_entries := reward_snapshot.get("entries", []) as Array
	_assert_true(
		not bool(reward_snapshot.get("uncertain", true)) \
			and reward_entries.size() == 1 \
			and str((reward_entries[0] as Dictionary).get("id", "")) == "reward_enemy",
		"Reward Protocol should preview its actual fixed reward target."
	)
	var late_snapshot := PANEL_SCRIPT.build_enemy_preview_snapshot("survival", 9) as Dictionary
	var elite_entry: Dictionary = {}
	for candidate in late_snapshot.get("entries", []) as Array:
		if bool((candidate as Dictionary).get("elite", false)):
			elite_entry = candidate as Dictionary
			break
	_assert_true(
		not elite_entry.is_empty() and elite_entry.get("texture") != null,
		"Enemy preview metadata should preserve the actual elite tag and portrait texture."
	)
	var elite_view := _panel.call("_make_enemy_preview_entry", elite_entry) as VBoxContainer
	var elite_name_row := elite_view.get_child(1) as HBoxContainer
	_assert_true(
		elite_name_row.get_child_count() == 2 \
			and (elite_name_row.get_child(1) as Label).text == "ELITE",
		"Elite candidates should render a visible elite badge beside their name."
	)
	elite_view.free()
	var rest_snapshot := PANEL_SCRIPT.build_enemy_preview_snapshot("rest", 1) as Dictionary
	_assert_true(
		bool(rest_snapshot.get("available", false)) \
			and (rest_snapshot.get("entries", []) as Array).is_empty(),
		"Rest Protocol should explicitly resolve to an available empty enemy preview."
	)
	_assert_true(_confirm_count == 0, "Selecting a protocol should not confirm it immediately.")
	confirm_button.disabled = false # The layout test runs outside the protocol-selection phase.
	_panel.call("_on_confirm_pressed")
	_assert_true(
		_confirm_count == 1 and bool(_panel.get("_locked")),
		"Explicit confirmation should launch the selected protocol exactly once (count=%d locked=%s)." % [
			_confirm_count,
			bool(_panel.get("_locked")),
		]
	)
	_panel.call("dismiss")
	_panel.call("open", [ELIMINATION, SURVIVAL], Callable(), Callable())
	await get_tree().process_frame
	_assert_true(
		select_range.text.contains("1–2") and not select_range.text.contains("1–3"),
		"Protocol selection should reduce its numeric shortcut range when only two options are owned."
	)
	_assert_true(
		not (_panel.get("cards") as Array)[2].visible,
		"The hidden third card should agree with the displayed 1–2 shortcut range."
	)

	var narrow_size: Vector2 = PANEL_SCRIPT.calculate_panel_size(Vector2(720.0, 720.0), true)
	_assert_true(
		narrow_size.is_equal_approx(Vector2(672.0, 688.0)),
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
		"Shade/Panel/Margin/Content/MainCards/CardRight"
	) as Button
	reward_card.call("set_selected", true, false)
	selected_badge = reward_card.get_node("Margin/Content/Header/SelectedBadge") as Label
	await get_tree().process_frame
	select_range = _panel.get_node("Shade/Panel/Margin/Content/Subtitle/SelectRange") as Label
	escape_icon = _panel.get_node("Shade/Panel/Margin/Content/Subtitle/EscapeIcon") as TextureRect
	_assert_true(
		select_range.text.contains("1–3") and escape_icon.texture != null,
		"Chinese protocol selection should localize the dynamic range and retain the Escape key icon."
	)
	_assert_true(
		selected_badge.text == "✓ 已选择",
		"Selected badge should localize to Chinese."
	)
	_assert_true(
		_panel.get_node("Shade/Panel/Margin/Content/TerminalStatus").text.contains("战术链路"),
		"Terminal status should localize instead of remaining English."
	)
	_assert_full_width_objective_copy(ELIMINATION)
	_assert_full_width_objective_copy(SURVIVAL)
	_assert_full_width_objective_copy(OPERATION)
	_assert_full_width_objective_copy(CONTAINMENT)
	_assert_full_width_objective_copy(EXTRACTION)

	print("FAIL: battle contract selection layout" if _failed else "PASS: battle contract selection layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _reset_runtime_state() -> void:
	LocalizationManager.set_locale("en", false)
	BattleContractManager.reset_runtime_state()
	_panel = null

func _on_contract_confirmed() -> void:
	_confirm_count += 1

func _assert_full_width_objective_copy(definition: Resource) -> void:
	var card := preload("res://UI/scenes/battle_contract_card.tscn").instantiate() as Button
	add_child(card)
	card.call("setup", definition)
	_assert_true(
		card.has_method("set_enhanced_mode") and not bool(card.call("is_enhanced_mode")),
		"Contract %s should expose an enhanced presentation interface that defaults off." % str(definition.contract_id)
	)
	card.call("set_enhanced_mode", true)
	_assert_true(
		not bool(card.call("is_enhanced_mode")) and not card.get_node("EnhancedFrame").visible,
		"Contract %s should reject enhanced mode until risk and reward content are available." % str(definition.contract_id)
	)
	var enhanced_toggle := card.get_node("EnhancementToggle") as CheckButton
	_assert_true(
		not enhanced_toggle.visible and not bool(card.call("is_enhanced_available")),
		"Contract %s should hide unfinished enhanced content by default." % str(definition.contract_id)
	)
	card.call("set_enhanced_offer", ["Enemies gain +20% movement speed"], ["Gold +40%"])
	_assert_true(
		enhanced_toggle.visible and bool(card.call("is_enhanced_available")),
		"Contract %s should reveal its enhanced toggle only when content becomes available." % str(definition.contract_id)
	)
	card.call("set_enhanced_mode", true)
	var enhanced_details := card.get_node("Margin/Content/EnhancedDetails") as VBoxContainer
	_assert_true(
		bool(card.call("is_enhanced_mode")) \
			and card.get_node("EnhancedFrame").visible \
			and enhanced_details.visible \
			and (enhanced_details.get_node("Risk") as Label).text.contains("Enemies gain") \
			and (enhanced_details.get_node("Bonus") as Label).text.contains("Gold +40%"),
		"Contract %s should show its armor frame and disclose both risk and reward when enhanced." % str(definition.contract_id)
	)
	card.call("set_enhanced_available", false)
	_assert_true(
		not enhanced_details.visible and not bool(card.call("is_enhanced_mode")),
		"Contract %s should clear enhanced disclosure when the offer becomes unavailable." % str(definition.contract_id)
	)
	var info_grid := card.get_node("Margin/Content/InfoGrid") as HBoxContainer
	_assert_true(
		info_grid.get_child_count() == 1 \
			and not card.has_node("Margin/Content/InfoGrid/Reward"),
		"Contract %s should show only its full-width core objective." % str(definition.contract_id)
	)
	card.queue_free()

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)
