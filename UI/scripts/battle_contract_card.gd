extends Button

const PRESENTATION := preload("res://UI/resources/protocols/catalog.tres")
@export var animations_enabled := true
var _art_tween: Tween
var _presentation: Dictionary = {}

signal enhanced_mode_changed(enabled: bool)

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")
const INTRO_DETAIL_FADE_MAX_SEC := 0.14
const STANDARD_BOTTOM_MARGIN := 14
const COMPACT_BOTTOM_MARGIN := 12
const ENHANCEMENT_TOGGLE_BOTTOM_CLEARANCE := 48

var definition: BattleContractDefinition
var _accent_color := Color(0.45, 0.65, 0.85)
var _selected := false
var _contract_id := ""
var _intro_mode := false
var _enhanced_mode := false
var _enhanced_available := false
var _compact_layout := false
var _enhanced_risk_lines: Array[String] = []
var _enhanced_reward_lines: Array[String] = []

func _ready() -> void:
	$EnhancementToggle.toggled.connect(_on_enhancement_toggled)
	$EnhancementToggle.gui_input.connect(_on_enhancement_gui_input)
	$Margin/Content/ObjectiveGap.resized.connect(_layout_art)

func setup(value: BattleContractDefinition) -> void:
	definition = value
	_intro_mode = false
	$Margin/Content/ObjectiveGap.visible = true
	$StateBadges.visible = true
	$Margin/Content/BodyScroll.scroll_vertical = 0
	_enhanced_risk_lines.clear()
	_enhanced_reward_lines.clear()
	set_enhanced_mode(false)
	set_enhanced_available(false)
	disabled = false
	modulate = Color.WHITE
	var id := str(definition.contract_id)
	_contract_id = id
	_accent_color = definition.accent_color.lightened(0.12)
	_presentation = PRESENTATION.entry(id)
	_accent_color = _presentation.get("tint", _accent_color)
	_apply_art()
	$Margin/Content/Title.text = LocalizationManager.tr_key(definition.name_key, id.capitalize())
	$Margin/Content/Title.tooltip_text = $Margin/Content/Title.text
	var objective := LocalizationManager.tr_key("battle_contract.card.%s.summary" % id, LocalizationManager.tr_key(definition.description_key, "Complete the contract objective."))
	var objective_label := LocalizationManager.tr_key("battle_contract.card.label.objective", "OBJECTIVE")
	var is_reward := id == "reward"
	$Margin/Content/BodyScroll/Body/InfoGrid.visible = not is_reward
	$Margin/Content/BodyScroll/Body/IntroContent.visible = false
	$Margin/Content/BodyScroll/Body/RewardDetails.visible = is_reward
	if id == "reward":
		var rule_label := LocalizationManager.tr_key("battle_contract.card.label.rule", "SPECIAL RULE")
		var special_rule := LocalizationManager.tr_key("battle_contract.card.reward.special_rule", "Targets do not attack")
		$Margin/Content/BodyScroll/Body/RewardDetails/Objective.text = "%s\n%s" % [objective_label, objective]
		$Margin/Content/BodyScroll/Body/RewardDetails/Rule.text = "%s\n%s" % [rule_label, special_rule]
	else:
		$Margin/Content/BodyScroll/Body/InfoGrid/Description.text = "%s\n%s" % [objective_label, objective]
	$Margin/Content/Header/TypeLabel.text = LocalizationManager.tr_key("battle_contract.card.type.%s" % id, _type_label(id))
	$Margin/Content/Header/RareBadge.text = LocalizationManager.tr_key("battle_contract.card.badge.rare", "RARE // 稀有")
	$Margin/Content/Header/RareBadge.visible = id == "reward"
	$Margin/Content/Header/SelectedBadge.text = LocalizationManager.tr_key(
		"battle_contract.card.badge.selected",
		"✓ SELECTED"
	)
	$RareFrame.visible = id == "reward"
	$StateBadges/Rare.visible = id == "reward"
	_apply_card_styles()
	set_selected(false, false)

func set_selected(value: bool, dim_unselected: bool = true) -> void:
	_selected = value
	button_pressed = value
	# Keep the badge in the header layout in both states. Removing it from the
	# HBox changes the header minimum width and makes the anchored content margin
	# expand, which in turn reflows every wrapped label in the card.
	$Margin/Content/Header/SelectedBadge.visible = not _intro_mode
	$Margin/Content/Header/SelectedBadge.modulate.a = 1.0 if value else 0.0
	_animate_art()
	$Margin/Content/Header/SelectionMark.text = ""
	$Margin/Content/Header/SelectionMark.add_theme_color_override(
		"font_color",
		_accent_color if value else Color(0.52, 0.64, 0.67, 0.95)
	)
	$SelectionRail.visible = value and not _intro_mode
	self_modulate = Color.WHITE if value or not dim_unselected else Color(0.84, 0.88, 0.9, 0.9)

func set_hold_progress(value: float, is_visible: bool) -> void:
	$HoldProgress.value = clampf(value, 0.0, 1.0)
	$HoldProgress.visible = is_visible

func set_enhanced_mode(value: bool) -> void:
	## Reserved presentation interface for enhanced-contract implementations.
	## Calling code remains responsible for risk rules, rewards, and persistence.
	_enhanced_mode = value and _enhanced_available
	$EnhancedFrame.visible = _enhanced_mode
	_animate_art()
	$EnhancementToggle.set_pressed_no_signal(_enhanced_mode)
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails.visible = _enhanced_mode and not _intro_mode
	_refresh_enhanced_copy()

func is_enhanced_mode() -> bool:
	return _enhanced_mode

func set_enhanced_available(value: bool) -> void:
	_enhanced_available = value \
		and not _enhanced_risk_lines.is_empty() \
		and not _enhanced_reward_lines.is_empty()
	$EnhancementToggle.visible = _enhanced_available and not _intro_mode
	$EnhancementToggle.text = LocalizationManager.tr_key(
		"battle_contract.card.enhanced_toggle.compact" if _compact_layout else "battle_contract.card.enhanced_toggle",
		"强化" if _compact_layout else "强化模式"
	)
	$EnhancementToggle.tooltip_text = "Enter 切换强化 · 空格确认" if LocalizationManager.get_locale() == "zh_CN" else "Enter toggles enhancement · Space confirms"
	_refresh_content_spacing()
	if not _enhanced_available:
		set_enhanced_mode(false)

func set_enhanced_offer(risk_lines: Array, reward_lines: Array) -> void:
	## Presentation/data boundary for protocols implemented one at a time. Runtime
	## owners supply only the incremental risk and incremental reward copy.
	_enhanced_risk_lines.clear()
	_enhanced_reward_lines.clear()
	for line in risk_lines:
		_enhanced_risk_lines.append(str(line))
	for line in reward_lines:
		_enhanced_reward_lines.append(str(line))
	set_enhanced_available(not _enhanced_risk_lines.is_empty() and not _enhanced_reward_lines.is_empty())
	_refresh_enhanced_copy()

func get_enhanced_risk_lines() -> Array[String]:
	return _enhanced_risk_lines.duplicate()

func get_enhanced_reward_lines() -> Array[String]:
	return _enhanced_reward_lines.duplicate()

func is_enhanced_available() -> bool:
	return _enhanced_available

func set_compact_layout(value: bool) -> void:
	_compact_layout = value
	$Margin.add_theme_constant_override("margin_left", 24)
	$Margin.add_theme_constant_override("margin_right", 24)
	$Margin.add_theme_constant_override("margin_top", 18)
	$Margin/Content/Header.add_theme_constant_override("separation", 6 if value else 9)
	$Margin/Content.add_theme_constant_override("separation", 6 if value else 8)
	$Margin/Content/ObjectiveGap.custom_minimum_size.y = 80.0
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails.add_theme_constant_override("separation", 3 if value else 7)
	$Margin/Content/Title.add_theme_font_size_override("font_size", 22)
	$Margin/Content/BodyScroll/Body/InfoGrid/Description.add_theme_font_size_override("font_size", 15 if value else 16)
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Risk.add_theme_font_size_override("font_size", 11 if value else 13)
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Bonus.add_theme_font_size_override("font_size", 11 if value else 13)
	for detail_label: Label in [
		$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Risk,
		$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Bonus,
	]:
		var detail_style := detail_label.get_theme_stylebox("normal")
		if detail_style != null:
			detail_style.content_margin_top = 1.0 if value else 3.0
			detail_style.content_margin_bottom = 1.0 if value else 3.0
	_refresh_content_spacing()
	set_enhanced_available(_enhanced_available)

func _refresh_content_spacing() -> void:
	# EnhancementToggle is deliberately anchored above the card's lower edge so it
	# stays easy to target. Reserve that same strip in the content layout whenever
	# the control is visible; otherwise localized bonus copy can flow underneath it.
	var bottom_margin := STANDARD_BOTTOM_MARGIN if _intro_mode else ENHANCEMENT_TOGGLE_BOTTOM_CLEARANCE
	$Margin.add_theme_constant_override("margin_bottom", bottom_margin)

func _on_enhancement_toggled(enabled: bool) -> void:
	set_enhanced_mode(enabled)
	enhanced_mode_changed.emit(enabled)

func _on_enhancement_gui_input(event: InputEvent) -> void:
	if disabled or not _enhanced_available:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		$EnhancementToggle.button_pressed = not $EnhancementToggle.button_pressed
		$EnhancementToggle.accept_event()

func set_quick_select_index(index: int) -> void:
	$Margin/Content/Header/KeyBadge.text = str(index)
	$Margin/Content/Header/KeyBadge.visible = index >= 1 and index <= 3

func show_battle_intro(objective: String, parameters_text: String) -> void:
	_intro_mode = true
	custom_minimum_size = Vector2.ZERO
	_refresh_content_spacing()
	$Margin.add_theme_constant_override("margin_top", 8)
	$Margin.add_theme_constant_override("margin_bottom", 8)
	$Margin/Content.add_theme_constant_override("separation", 4)
	$Margin/Content/Header/ContractIcon.custom_minimum_size = Vector2(24, 24)
	$Margin/Content/Title.add_theme_font_size_override("font_size", 20)
	$Margin/Content/BodyScroll/Body/IntroContent.add_theme_constant_override("separation", 4)
	$Margin/Content/BodyScroll/Body/IntroContent/Objective.add_theme_font_size_override("font_size", 18)
	$Margin/Content/BodyScroll/Body/IntroContent/Parameters.add_theme_font_size_override("font_size", 12)
	$Margin/Content/BodyScroll.scroll_vertical = 0
	$Margin/Content/Header/KeyBadge.visible = false
	$Margin/Content/Header/SelectedBadge.visible = false
	$Margin/Content/Header/RareBadge.visible = false
	$EnhancementToggle.visible = false
	$RareFrame.visible = false
	$SelectionRail.visible = false
	$Margin/Content/ObjectiveGap.visible = false
	$StateBadges.visible = false
	$Margin/Content/BodyScroll/Body/InfoGrid.visible = false
	$Margin/Content/BodyScroll/Body/IntroContent.visible = true
	$Margin/Content/BodyScroll/Body/IntroContent/Objective.text = objective
	$Margin/Content/BodyScroll/Body/IntroContent/Parameters.text = parameters_text
	$Margin/Content/BodyScroll/Body/IntroContent/Parameters.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header.alignment = BoxContainer.ALIGNMENT_CENTER
	$Margin/Content/Header/TypeLabel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Margin/Content/Header/TypeLabel.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	$Margin/Content/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Margin/Content/BodyScroll/Body/RewardDetails.visible = false
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails.visible = false

func _refresh_enhanced_copy() -> void:
	var risk_title := LocalizationManager.tr_key("battle_contract.card.enhanced_risk", "ENHANCED RISK")
	var reward_title := LocalizationManager.tr_key("battle_contract.card.enhanced_reward", "EXTRA REWARD")
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Risk.text = "%s\n◆ %s" % [risk_title, "\n◆ ".join(_enhanced_risk_lines)]
	$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Bonus.text = "%s\n◆ %s" % [reward_title, "\n◆ ".join(_enhanced_reward_lines)]

func begin_intro_collapse(duration_sec: float) -> void:
	## Fade secondary copy before the card becomes the compact objective HUD. Keeping
	## the title/header readable preserves the visual identity during the hand-off.
	clip_contents = true
	if not animations_enabled:
		$Margin/Content/BodyScroll/Body/IntroContent.modulate.a = 0.0
		return
	var fade_duration := minf(
		INTRO_DETAIL_FADE_MAX_SEC,
		maxf(duration_sec, 0.08)
	)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($Margin/Content/BodyScroll/Body/IntroContent/Objective, "modulate:a", 0.0, fade_duration)
	tween.tween_property($Margin/Content/BodyScroll/Body/IntroContent/Parameters, "modulate:a", 0.0, fade_duration)

func _apply_card_styles() -> void:
	var frame_key := str(_presentation.get("frame", "frame"))
	add_theme_stylebox_override("normal", PRESENTATION.style(frame_key))
	add_theme_stylebox_override("hover", PRESENTATION.style(frame_key, Color(1.2, 1.35, 1.4)))
	add_theme_stylebox_override("pressed", PRESENTATION.style(frame_key))
	add_theme_stylebox_override("hover_pressed", PRESENTATION.style(frame_key, Color(1.2, 1.35, 1.4)))
	add_theme_stylebox_override("disabled", PRESENTATION.style(frame_key, Color(0.6, 0.65, 0.7)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new() if PRESENTATION.texture("focus_badge") != null else PRESENTATION.style("selected", Color.WHITE, false))
	$RareFrame.add_theme_stylebox_override("panel", PRESENTATION.style("selected", Color(0.9, 0.65, 0.2), false))
	$Margin/Content/Header/TypeLabel.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header/KeyBadge.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	$HoldProgress.add_theme_stylebox_override("background", PRESENTATION.progress_style(false))
	$HoldProgress.add_theme_stylebox_override("fill", PRESENTATION.progress_style(true, _accent_color))
	for label in [$Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Risk, $Margin/Content/BodyScroll/Body/ContentSpacer/EnhancedDetails/Bonus]:
		label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_apply_enhancement_toggle_styles()

func _apply_art() -> void:
	var art := PRESENTATION.load_texture(str(_presentation.get("illustration", "")))
	$Margin/Content/ObjectiveGap/Illustration.texture = art
	_layout_art()
	$Margin/Content/ObjectiveGap/Missing.visible = art == null
	$Margin/Content/ObjectiveGap/Missing.text = "图像离线 · 协议仍可选择" if LocalizationManager.get_locale() == "zh_CN" else "ART OFFLINE · PROTOCOL AVAILABLE"
	var symbol := PRESENTATION.load_texture(str(_presentation.get("icon", "")))
	$Margin/Content/Header/ContractIcon.texture = symbol if symbol != null else PRESENTATION.texture("fallback_icon")
	$SelectionRail.texture = PRESENTATION.texture("selected")
	$EnhancedFrame.texture = PRESENTATION.texture("selected")
	$EnhancedFrame.modulate = Color(1.0, 0.65, 0.25)
	$FocusFrame.texture = PRESENTATION.texture("focus_badge")
	for pair in [["Rare", "rare_badge"], ["Disabled", "disabled_badge"]]:
		get_node("StateBadges/" + pair[0]).texture = PRESENTATION.texture(pair[1])

func _layout_art() -> void:
	var illustration := $Margin/Content/ObjectiveGap/Illustration as TextureRect
	if illustration.texture == null:
		return
	var area := $Margin/Content/ObjectiveGap as Control
	var focal: Vector2 = _presentation.get("focal_point", Vector2(0.5, 0.5))
	illustration.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	illustration.size = illustration.texture.get_size()
	illustration.position = Vector2(
		clampf(area.size.x * 0.5 - illustration.size.x * focal.x, 0.0, maxf(0.0, area.size.x - illustration.size.x)),
		maxf(0.0, (area.size.y - illustration.size.y) * 0.5)
	).round()

func _process(_delta: float) -> void:
	$EnhancementToggle.disabled = disabled
	$StateBadges/Disabled.visible = disabled and not _intro_mode
	$FocusFrame.visible = has_focus() and not disabled and not _intro_mode

func _animate_art() -> void:
	if _art_tween != null:
		_art_tween.kill()
	$Margin/Content/ObjectiveGap.modulate = Color.WHITE
	if animations_enabled and is_inside_tree():
		$Margin/Content/ObjectiveGap.modulate = Color(0.75, 0.8, 0.85)
		_art_tween = create_tween()
		_art_tween.tween_property($Margin/Content/ObjectiveGap, "modulate", Color.WHITE, 0.16)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEDOWN, KEY_PAGEUP]:
		$Margin/Content/BodyScroll.scroll_vertical += 64 if event.keycode == KEY_PAGEDOWN else -64
		accept_event()

func _type_label(id: String) -> String:
	match id:
		"survival": return "SURVIVAL // 坚守"
		"elimination": return "ELIMINATION // 歼灭"
		"reward": return "BOUNTY // 奖励"
		"rest": return "LOGISTICS // 整备"
		"operation": return "OPERATION // 行动"
		"containment": return "CONTAINMENT // 封锁"
		"extraction": return "EXTRACTION // 撤离"
		"finale": return "最终" if LocalizationManager.get_locale() == "zh_CN" else "FINALE"
		_: return "CONTRACT // 协议"

func _apply_enhancement_toggle_styles() -> void:
	var toggle := $EnhancementToggle as CheckButton
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		toggle.add_theme_stylebox_override(state, PRESENTATION.style("button"))
	toggle.add_theme_stylebox_override("focus", PRESENTATION.style("selected", Color.WHITE, false))
	for state in ["checked", "checked_disabled"]:
		if PRESENTATION.texture("enhanced_badge") != null:
			toggle.add_theme_icon_override(state, PRESENTATION.texture("enhanced_badge"))
	for state in ["unchecked", "unchecked_disabled"]:
		if PRESENTATION.texture("enhanced_badge") != null:
			toggle.add_theme_icon_override(state, PRESENTATION.texture("enhanced_badge"))
	toggle.add_theme_color_override("icon_normal_color", Color(0.4, 0.45, 0.5))
	toggle.add_theme_color_override("icon_pressed_color", Color.WHITE)
