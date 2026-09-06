extends Button

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

func setup(value: BattleContractDefinition) -> void:
	definition = value
	_intro_mode = false
	_enhanced_risk_lines.clear()
	_enhanced_reward_lines.clear()
	set_enhanced_mode(false)
	set_enhanced_available(false)
	disabled = false
	modulate = Color.WHITE
	var id := str(definition.contract_id)
	_contract_id = id
	_accent_color = definition.accent_color.lightened(0.12)
	$Margin/Content/Header/ContractIcon.call("setup", id, _accent_color)
	$Margin/Content/Title.text = LocalizationManager.tr_key(definition.name_key, id.capitalize())
	var objective := LocalizationManager.tr_key("battle_contract.card.%s.summary" % id, "Complete the contract objective.")
	var objective_label := LocalizationManager.tr_key("battle_contract.card.label.objective", "OBJECTIVE")
	var is_reward := id == "reward"
	$Margin/Content/InfoGrid.visible = not is_reward
	$Margin/Content/IntroContent.visible = false
	$Margin/Content/RewardDetails.visible = is_reward
	if id == "reward":
		var rule_label := LocalizationManager.tr_key("battle_contract.card.label.rule", "SPECIAL RULE")
		var special_rule := LocalizationManager.tr_key("battle_contract.card.reward.special_rule", "Targets do not attack")
		$Margin/Content/RewardDetails/Objective.text = "%s\n%s" % [objective_label, objective]
		$Margin/Content/RewardDetails/Rule.text = "%s\n%s" % [rule_label, special_rule]
	else:
		$Margin/Content/InfoGrid/Description.text = "%s\n%s" % [objective_label, objective]
	$Margin/Content/Header/TypeLabel.text = LocalizationManager.tr_key("battle_contract.card.type.%s" % id, _type_label(id))
	$Margin/Content/Header/RareBadge.text = LocalizationManager.tr_key("battle_contract.card.badge.rare", "RARE // 稀有")
	$Margin/Content/Header/RareBadge.visible = id == "reward"
	$Margin/Content/Header/SelectedBadge.text = LocalizationManager.tr_key(
		"battle_contract.card.badge.selected",
		"✓ SELECTED"
	)
	$RareFrame.visible = id == "reward"
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
	$Margin/Content/Header/SelectionMark.text = "●" if value else "○"
	$Margin/Content/Header/SelectionMark.add_theme_color_override(
		"font_color",
		_accent_color if value else Color(0.52, 0.64, 0.67, 0.95)
	)
	$AccentLine.offset_right = 8.0 if value else 6.0
	$SelectionRail.visible = value and not _intro_mode
	$SelectionRail.color = _accent_color
	self_modulate = Color.WHITE if value or not dim_unselected else Color(0.84, 0.88, 0.9, 0.9)

func set_hold_progress(value: float, is_visible: bool) -> void:
	$HoldProgress.value = clampf(value, 0.0, 1.0)
	$HoldProgress.visible = is_visible

func set_enhanced_mode(value: bool) -> void:
	## Reserved presentation interface for enhanced-contract implementations.
	## Calling code remains responsible for risk rules, rewards, and persistence.
	_enhanced_mode = value and _enhanced_available
	$EnhancedFrame.call("set_enhanced", _enhanced_mode, _accent_color)
	$EnhancementToggle.set_pressed_no_signal(_enhanced_mode)
	$Margin/Content/ContentSpacer/EnhancedDetails.visible = _enhanced_mode and not _intro_mode
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
	$Margin.add_theme_constant_override("margin_left", 18 if value else 24)
	$Margin.add_theme_constant_override("margin_right", 18 if value else 24)
	$Margin.add_theme_constant_override("margin_top", 12 if value else 14)
	$Margin/Content/Header.add_theme_constant_override("separation", 6 if value else 9)
	$Margin/Content.add_theme_constant_override("separation", 6 if value else 8)
	$Margin/Content/ObjectiveGap.custom_minimum_size.y = 12.0
	$Margin/Content/ContentSpacer/EnhancedDetails.add_theme_constant_override("separation", 3 if value else 7)
	$Margin/Content/Title.add_theme_font_size_override("font_size", 22 if value else 25)
	$Margin/Content/InfoGrid/Description.add_theme_font_size_override("font_size", 15 if value else 16)
	$Margin/Content/ContentSpacer/EnhancedDetails/Risk.add_theme_font_size_override("font_size", 11 if value else 13)
	$Margin/Content/ContentSpacer/EnhancedDetails/Bonus.add_theme_font_size_override("font_size", 11 if value else 13)
	for detail_label: Label in [
		$Margin/Content/ContentSpacer/EnhancedDetails/Risk,
		$Margin/Content/ContentSpacer/EnhancedDetails/Bonus,
	]:
		var detail_style := detail_label.get_theme_stylebox("normal") as StyleBoxFlat
		if detail_style != null:
			detail_style.content_margin_top = 1.0 if value else 3.0
			detail_style.content_margin_bottom = 1.0 if value else 3.0
	_refresh_content_spacing()
	set_enhanced_available(_enhanced_available)

func _refresh_content_spacing() -> void:
	# EnhancementToggle is deliberately anchored above the card's lower edge so it
	# stays easy to target. Reserve that same strip in the content layout whenever
	# the control is visible; otherwise localized bonus copy can flow underneath it.
	var bottom_margin := ENHANCEMENT_TOGGLE_BOTTOM_CLEARANCE \
		if _enhanced_available and not _intro_mode \
		else (COMPACT_BOTTOM_MARGIN if _compact_layout else STANDARD_BOTTOM_MARGIN)
	$Margin.add_theme_constant_override("margin_bottom", bottom_margin)

func _on_enhancement_toggled(enabled: bool) -> void:
	set_enhanced_mode(enabled)
	enhanced_mode_changed.emit(enabled)

func set_quick_select_index(index: int) -> void:
	$Margin/Content/Header/KeyBadge.text = str(index)
	$Margin/Content/Header/KeyBadge.visible = index >= 1 and index <= 3

func show_battle_intro(objective: String, parameters_text: String) -> void:
	_intro_mode = true
	$Margin/Content/Header/KeyBadge.visible = false
	$Margin/Content/Header/SelectedBadge.visible = false
	$Margin/Content/Header/RareBadge.visible = false
	$EnhancementToggle.visible = false
	$RareFrame.visible = false
	$SelectionRail.visible = false
	$Margin/Content/ObjectiveGap.visible = false
	$Margin/Content/InfoGrid.visible = false
	$Margin/Content/IntroContent.visible = true
	$Margin/Content/IntroContent/Objective.text = objective
	$Margin/Content/IntroContent/Parameters.text = parameters_text
	$Margin/Content/IntroContent/Parameters.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header.alignment = BoxContainer.ALIGNMENT_CENTER
	$Margin/Content/Header/TypeLabel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Margin/Content/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Margin/Content/RewardDetails.visible = false
	$Margin/Content/ContentSpacer/EnhancedDetails.visible = false

func _refresh_enhanced_copy() -> void:
	var risk_title := LocalizationManager.tr_key("battle_contract.card.enhanced_risk", "ENHANCED RISK")
	var reward_title := LocalizationManager.tr_key("battle_contract.card.enhanced_reward", "EXTRA REWARD")
	$Margin/Content/ContentSpacer/EnhancedDetails/Risk.text = "%s\n◆ %s" % [risk_title, "\n◆ ".join(_enhanced_risk_lines)]
	$Margin/Content/ContentSpacer/EnhancedDetails/Bonus.text = "%s\n◆ %s" % [reward_title, "\n◆ ".join(_enhanced_reward_lines)]

func begin_intro_collapse(duration_sec: float) -> void:
	## Fade secondary copy before the card becomes the compact objective HUD. Keeping
	## the title/header readable preserves the visual identity during the hand-off.
	clip_contents = true
	var fade_duration := minf(
		INTRO_DETAIL_FADE_MAX_SEC,
		maxf(duration_sec, 0.08)
	)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property($Margin/Content/IntroContent/Objective, "modulate:a", 0.0, fade_duration)
	tween.tween_property($Margin/Content/IntroContent/Parameters, "modulate:a", 0.0, fade_duration)

func _apply_card_styles() -> void:
	var card_dark := Color(0.045, 0.07, 0.083, 0.985)
	var key_badge_style := StyleBoxFlat.new()
	key_badge_style.bg_color = Color(0.025, 0.055, 0.065, 0.96)
	key_badge_style.border_color = _accent_color.darkened(0.12)
	key_badge_style.set_border_width_all(1)
	key_badge_style.set_corner_radius_all(3)
	$Margin/Content/Header/KeyBadge.add_theme_stylebox_override("normal", key_badge_style)
	var hold_track := StyleBoxFlat.new()
	hold_track.bg_color = Color(0.015, 0.03, 0.035, 0.95)
	hold_track.set_corner_radius_all(2)
	var hold_fill := StyleBoxFlat.new()
	hold_fill.bg_color = _accent_color
	hold_fill.set_corner_radius_all(2)
	$HoldProgress.add_theme_stylebox_override("background", hold_track)
	$HoldProgress.add_theme_stylebox_override("fill", hold_fill)
	$AccentLine.color = _accent_color
	$EnhancedFrame.set("frame_color", _accent_color)
	$Margin/Content/Header/TypeLabel.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header/RareBadge.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	$Margin/Content/Title.add_theme_color_override("font_color", Color(0.91, 0.95, 0.96))
	$Margin/Content/InfoGrid/Description.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/IntroContent/Objective.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/RewardDetails/Objective.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/RewardDetails/Rule.add_theme_color_override("font_color", Color(0.92, 0.72, 0.25))
	$Margin/Content/ContentSpacer/EnhancedDetails/Risk.add_theme_color_override("font_color", Color(1.0, 0.53, 0.31))
	$Margin/Content/ContentSpacer/EnhancedDetails/Bonus.add_theme_color_override("font_color", Color(0.96, 0.78, 0.28))
	$Margin/Content/ContentSpacer/EnhancedDetails/Risk.add_theme_stylebox_override(
		"normal", _make_detail_style(Color(0.24, 0.075, 0.035, 0.72), Color(0.9, 0.29, 0.16, 0.78))
	)
	$Margin/Content/ContentSpacer/EnhancedDetails/Bonus.add_theme_stylebox_override(
		"normal", _make_detail_style(Color(0.20, 0.14, 0.025, 0.72), Color(0.9, 0.62, 0.12, 0.78))
	)
	_apply_enhancement_toggle_styles()
	add_theme_stylebox_override("normal", _make_style(card_dark, Color(0.24, 0.36, 0.4, 0.9), 1))
	add_theme_stylebox_override("hover", _make_style(card_dark.lightened(0.035), _accent_color.darkened(0.18), 2))
	add_theme_stylebox_override("pressed", _make_style(card_dark.lightened(0.08), _accent_color.darkened(0.08), 1))
	var rare_style := _make_style(Color.TRANSPARENT, Color(0.72, 0.48, 0.12, 0.72), 1)
	rare_style.set_corner_radius_all(2)
	$RareFrame.add_theme_stylebox_override("panel", rare_style)

	# Focus only identifies the keyboard/controller cursor. Selection is communicated
	# separately by the stronger pressed style and the check badge.
	var focus_style := _make_style(Color(0, 0, 0, 0), Color(0.38, 0.58, 0.63, 0.55), 1)
	add_theme_stylebox_override("focus", focus_style)

func _type_label(id: String) -> String:
	match id:
		"survival": return "SURVIVAL // 坚守"
		"elimination": return "ELIMINATION // 歼灭"
		"reward": return "BOUNTY // 奖励"
		"rest": return "LOGISTICS // 整备"
		"operation": return "OPERATION // 行动"
		"containment": return "CONTAINMENT // 封锁"
		"extraction": return "EXTRACTION // 撤离"
		_: return "CONTRACT // 协议"

func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3, 3)
	return style

func _make_detail_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 3
	style.content_margin_left = 9.0
	style.content_margin_top = 3.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 3.0
	style.set_corner_radius_all(2)
	return style

func _apply_enhancement_toggle_styles() -> void:
	var toggle := $EnhancementToggle as CheckButton
	var normal := _make_style(Color(0.035, 0.09, 0.115, 0.98), Color(0.16, 0.55, 0.68, 0.95), 1)
	normal.shadow_size = 0
	var hover := _make_style(Color(0.055, 0.15, 0.18, 1.0), Color(0.34, 0.82, 0.92, 1.0), 2)
	hover.shadow_size = 0
	var pressed := _make_style(Color(0.18, 0.12, 0.025, 1.0), Color(1.0, 0.64, 0.12, 1.0), 2)
	pressed.shadow_size = 0
	toggle.add_theme_stylebox_override("normal", normal)
	toggle.add_theme_stylebox_override("hover", hover)
	toggle.add_theme_stylebox_override("pressed", pressed)
	toggle.add_theme_stylebox_override("hover_pressed", pressed)
	toggle.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.48))
