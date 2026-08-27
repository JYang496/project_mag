extends Control

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const ENHANCED_FRAME := preload("res://UI/scripts/components/enhanced_contract_frame.gd")

const OPERATION_COLOR := Color(0.545, 0.424, 0.878, 1.0)
const RISK_COLOR := Color(1.0, 0.463, 0.18, 1.0)


func _ready() -> void:
	_build_showcase()
	if "--capture-contract-difficulty" in OS.get_cmdline_user_args():
		call_deferred("_capture_preview")
		return
	if DisplayServer.get_name() == "headless":
		call_deferred("_validate_showcase")


func _build_showcase() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = TOKENS.COLOR_CANVAS
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_label("协议难度对比", 30, TOKENS.COLOR_TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(_label("先选择协议，再决定是否签署强化条款", 16, TOKENS.COLOR_TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))

	var divider := HSeparator.new()
	divider.custom_minimum_size.y = 2
	root.add_child(divider)

	var cards := HBoxContainer.new()
	cards.name = "ComparisonCards"
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 24)
	root.add_child(cards)
	cards.add_child(_build_contract_card(false))
	cards.add_child(_build_contract_card(true))

	root.add_child(_label("卡片只展示协议目标；开启强化模式后显示新增风险与对应额外收益。", 14, TOKENS.COLOR_TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _build_contract_card(enhanced: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "EnhancedContractCard" if enhanced else "StandardContractCard"
	card.custom_minimum_size.x = 574
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var enhanced_frame := ENHANCED_FRAME.new()
	enhanced_frame.name = "EnhancedFrame"
	enhanced_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enhanced_frame.frame_color = OPERATION_COLOR
	card.add_child(enhanced_frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var badge := _label("◆", 22, OPERATION_COLOR)
	badge.name = "ContractGlyph"
	badge.custom_minimum_size.x = 28
	header.add_child(badge)
	var type_label := _label("普通协议", 17, OPERATION_COLOR)
	type_label.name = "DifficultyLabel"
	type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(type_label)
	var difficulty_toggle := CheckButton.new()
	difficulty_toggle.name = "DifficultyToggle"
	difficulty_toggle.text = "强化模式"
	difficulty_toggle.button_pressed = enhanced
	difficulty_toggle.tooltip_text = "开启后增加强化条款与额外收益"
	difficulty_toggle.add_theme_font_size_override("font_size", 14)
	difficulty_toggle.add_theme_color_override("font_color", TOKENS.COLOR_TEXT_SECONDARY)
	difficulty_toggle.add_theme_color_override("font_pressed_color", OPERATION_COLOR.lightened(0.18))
	header.add_child(difficulty_toggle)

	content.add_child(_label("行动协议", 30, TOKENS.COLOR_TEXT_PRIMARY))
	content.add_child(_label("占领两个战术信标，敌人进入范围时会降低充能速度。", 17, TOKENS.COLOR_TEXT_SECONDARY))

	var objective := _section("基础目标", "依次完成两个信标的充能", OPERATION_COLOR)
	content.add_child(objective)

	var risk := _section("强化条款未启用", "本场不附加额外风险", TOKENS.COLOR_TEXT_MUTED)
	risk.name = "RiskSection"
	content.add_child(risk)

	var bonus := _section("额外收益", "开启强化模式后可获得", TOKENS.COLOR_TEXT_MUTED)
	bonus.name = "BonusSection"
	content.add_child(bonus)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var action := Button.new()
	action.name = "ConfirmButton"
	action.custom_minimum_size.y = TOKENS.BUTTON_HEIGHT_LARGE
	content.add_child(action)
	difficulty_toggle.toggled.connect(_on_difficulty_toggled.bind(card))
	_apply_enhanced_state(card, enhanced)
	return card


func _section(title: String, body: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.075)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.border_width_left = 3
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.name = "SectionContent"
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title_label := _label(title, 14, accent)
	title_label.name = "SectionTitle"
	box.add_child(title_label)
	var body_label := _label(body, 16, TOKENS.COLOR_TEXT_PRIMARY)
	body_label.name = "SectionBody"
	box.add_child(body_label)
	return panel


func _label(text_value: String, size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = alignment
	TOKENS.style_label(label, size, color)
	return label


func _apply_button_styles(button: Button, accent: Color, enhanced: bool) -> void:
	var background := Color(accent.r, accent.g, accent.b, 0.22 if enhanced else 0.12)
	var styles := TOKENS.make_button_style(background, accent)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TOKENS.COLOR_TEXT_PRIMARY)


func _on_difficulty_toggled(enabled: bool, card: PanelContainer) -> void:
	_apply_enhanced_state(card, enabled)


func _apply_enhanced_state(card: PanelContainer, enhanced: bool) -> void:
	var accent := OPERATION_COLOR
	var style := TOKENS.make_panel_style(true, accent)
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)

	var glyph := card.find_child("ContractGlyph", true, false) as Label
	var difficulty_label := card.find_child("DifficultyLabel", true, false) as Label
	var risk := card.find_child("RiskSection", true, false) as PanelContainer
	var bonus := card.find_child("BonusSection", true, false) as PanelContainer
	var action := card.find_child("ConfirmButton", true, false) as Button
	var enhanced_frame := card.find_child("EnhancedFrame", true, false) as Control
	if enhanced_frame != null:
		enhanced_frame.set("enhanced", enhanced)
	if glyph != null:
		glyph.add_theme_color_override("font_color", accent)
	if difficulty_label != null:
		difficulty_label.text = "强化协议" if enhanced else "普通协议"
		difficulty_label.add_theme_color_override("font_color", accent)
	_set_section_state(
		risk,
		"强化条款" if enhanced else "强化条款未启用",
		"精英进入范围时，信标停止充能\n敌军生成压力提高" if enhanced else "本场不附加额外风险",
		RISK_COLOR if enhanced else TOKENS.COLOR_TEXT_MUTED
	)
	_set_section_state(
		bonus,
		"额外收益",
		"免费刷新一次战后奖励" if enhanced else "开启强化模式后可获得",
		TOKENS.COLOR_REWARD if enhanced else TOKENS.COLOR_TEXT_MUTED
	)
	if action != null:
		action.text = "长按签署强化协议" if enhanced else "长按签署普通协议"
		_apply_button_styles(action, accent, enhanced)


func _set_section_state(panel: PanelContainer, title: String, body: String, accent: Color) -> void:
	if panel == null:
		return
	var title_label := panel.find_child("SectionTitle", true, false) as Label
	var body_label := panel.find_child("SectionBody", true, false) as Label
	if title_label != null:
		title_label.text = title
		title_label.add_theme_color_override("font_color", accent)
	if body_label != null:
		body_label.text = body
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.075)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.border_width_left = 3
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)


func _capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_dir := ProjectSettings.globalize_path("res://output/showcases/ui")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("contract_difficulty_frame_preview.png")
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error == OK:
		print("CAPTURED: %s" % output_path)
	else:
		push_error("ContractDifficultyComparisonShowcase: capture failed (%d)" % error)
	get_tree().quit(0 if error == OK else 1)


func _validate_showcase() -> void:
	await get_tree().process_frame
	var standard := find_child("StandardContractCard", true, false) as Control
	var enhanced := find_child("EnhancedContractCard", true, false) as Control
	var standard_toggle := standard.find_child("DifficultyToggle", true, false) as CheckButton if standard != null else null
	var enhanced_toggle := enhanced.find_child("DifficultyToggle", true, false) as CheckButton if enhanced != null else null
	var valid := standard != null and enhanced != null
	valid = valid and standard.size.x >= 560.0 and enhanced.size.x >= 560.0
	valid = valid and standard.get_global_rect().intersection(enhanced.get_global_rect()).size == Vector2.ZERO
	valid = valid and standard.get_global_rect().end.y <= size.y and enhanced.get_global_rect().end.y <= size.y
	valid = valid and standard_toggle != null and enhanced_toggle != null
	valid = valid and not standard_toggle.button_pressed and enhanced_toggle.button_pressed
	if standard_toggle != null:
		standard_toggle.button_pressed = true
		valid = valid and (standard.find_child("DifficultyLabel", true, false) as Label).text == "强化协议"
		standard_toggle.button_pressed = false
		valid = valid and (standard.find_child("DifficultyLabel", true, false) as Label).text == "普通协议"
	valid = valid and enhanced.find_child("RiskSection", true, false) != null
	valid = valid and enhanced.find_child("BonusSection", true, false) != null
	if valid:
		print("PASS: contract difficulty comparison showcase has distinct non-overlapping states")
	else:
		push_error("ContractDifficultyComparisonShowcase: invalid comparison geometry or missing semantics")
	await TEST_TEARDOWN.finish(self, 0 if valid else 1)
