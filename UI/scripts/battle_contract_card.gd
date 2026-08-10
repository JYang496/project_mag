extends Button

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")
const INTRO_DETAIL_FADE_MAX_SEC := 0.14

var definition: BattleContractDefinition
var _accent_color := Color(0.45, 0.65, 0.85)
var _selected := false
var _contract_id := ""
var _intro_mode := false

func setup(value: BattleContractDefinition) -> void:
	definition = value
	_intro_mode = false
	disabled = false
	modulate = Color.WHITE
	var id := str(definition.contract_id)
	_contract_id = id
	_accent_color = definition.accent_color.lightened(0.12)
	$Margin/Content/Title.text = LocalizationManager.tr_key(definition.name_key, id.capitalize())
	var objective := LocalizationManager.tr_key("battle_contract.card.%s.summary" % id, "Complete the contract objective.")
	var objective_label := LocalizationManager.tr_key("battle_contract.card.label.objective", "OBJECTIVE")
	var reward_hint := LocalizationManager.tr_key("battle_contract.card.%s.reward_hint" % id, "")
	var reward_label := LocalizationManager.tr_key("battle_contract.card.label.reward", "REWARD")
	var is_reward := id == "reward"
	$Margin/Content/InfoGrid.visible = not is_reward
	$Margin/Content/IntroContent.visible = false
	$Margin/Content/RewardDetails.visible = is_reward
	if id == "reward":
		var rule_label := LocalizationManager.tr_key("battle_contract.card.label.rule", "SPECIAL RULE")
		var special_rule := LocalizationManager.tr_key("battle_contract.card.reward.special_rule", "Targets do not attack")
		$Margin/Content/RewardDetails/Objective.text = "%s\n%s" % [objective_label, objective]
		$Margin/Content/RewardDetails/Rule.text = "%s\n%s" % [rule_label, special_rule]
		$Margin/Content/RewardDetails/Reward.text = "%s\n%s" % [reward_label, reward_hint]
	else:
		$Margin/Content/InfoGrid/Description.text = "%s\n%s" % [objective_label, objective]
		$Margin/Content/InfoGrid/Reward.text = "%s\n%s" % [reward_label, reward_hint]
	$Margin/Content/Header/TypeLabel.text = LocalizationManager.tr_key("battle_contract.card.type.%s" % id, _type_label(id))
	$Margin/Content/Header/RareBadge.text = LocalizationManager.tr_key("battle_contract.card.badge.rare", "RARE // 稀有")
	$Margin/Content/Header/RareBadge.visible = id == "reward"
	$Margin/Content/Header/SelectedBadge.text = LocalizationManager.tr_key(
		"battle_contract.card.badge.selected",
		"✓ SELECTED"
	)
	$RareFrame.visible = id == "reward"
	_apply_card_styles()
	queue_redraw()
	set_selected(false, false)

func set_selected(value: bool, dim_unselected: bool = true) -> void:
	_selected = value
	button_pressed = value
	$Margin/Content/Header/SelectedBadge.visible = value
	$Margin/Content/Header/SelectionMark.text = "●" if value else "○"
	$Margin/Content/Header/SelectionMark.add_theme_color_override(
		"font_color",
		_accent_color if value else Color(0.52, 0.64, 0.67, 0.95)
	)
	self_modulate = Color.WHITE if value or not dim_unselected else Color(0.84, 0.88, 0.9, 0.9)

func set_hold_progress(value: float, is_visible: bool) -> void:
	$HoldProgress.value = clampf(value, 0.0, 1.0)
	$HoldProgress.visible = is_visible

func set_quick_select_index(index: int) -> void:
	$Margin/Content/Header/KeyBadge.text = str(index)
	$Margin/Content/Header/KeyBadge.visible = index >= 1 and index <= 3

func show_battle_intro(objective: String, parameters_text: String) -> void:
	_intro_mode = true
	$Margin/Content/Header/KeyBadge.visible = false
	$Margin/Content/Header/SelectedBadge.visible = false
	$Margin/Content/Header/RareBadge.visible = false
	$RareFrame.visible = false
	$Margin/Content/InfoGrid.visible = false
	$Margin/Content/IntroContent.visible = true
	$Margin/Content/IntroContent/Objective.text = objective
	$Margin/Content/IntroContent/Parameters.text = parameters_text
	$Margin/Content/IntroContent/Parameters.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header.alignment = BoxContainer.ALIGNMENT_CENTER
	$Margin/Content/Header/TypeLabel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Margin/Content/Title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Margin/Content/RewardDetails.visible = false
	queue_redraw()

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
	$Margin/Content/Header/TypeLabel.add_theme_color_override("font_color", _accent_color)
	$Margin/Content/Header/RareBadge.add_theme_color_override("font_color", Color(1.0, 0.78, 0.26))
	$Margin/Content/Title.add_theme_color_override("font_color", Color(0.91, 0.95, 0.96))
	$Margin/Content/InfoGrid/Description.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/InfoGrid/Reward.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38) if _contract_id == "reward" else Color(0.76, 0.83, 0.85))
	$Margin/Content/IntroContent/Objective.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/RewardDetails/Objective.add_theme_color_override("font_color", Color(0.82, 0.89, 0.91))
	$Margin/Content/RewardDetails/Rule.add_theme_color_override("font_color", Color(0.92, 0.72, 0.25))
	$Margin/Content/RewardDetails/Reward.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	add_theme_stylebox_override("normal", _make_style(card_dark, Color(0.24, 0.36, 0.4, 0.9), 1))
	add_theme_stylebox_override("hover", _make_style(card_dark.lightened(0.035), _accent_color.darkened(0.18), 2))
	add_theme_stylebox_override("pressed", _make_style(card_dark.lightened(0.06), _accent_color, 3))
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

func _draw() -> void:
	var center := get_contract_icon_center_local()
	var color := _accent_color
	match _contract_id:
		"survival":
			# Stopwatch: circular dial, crown, and hand.
			draw_arc(center, 9.0, 0.0, TAU, 24, color, 2.0, true)
			draw_line(center + Vector2(0, -13), center + Vector2(0, -9), color, 2.0, true)
			draw_line(center + Vector2(-3, -13), center + Vector2(3, -13), color, 2.0, true)
			draw_line(center, center + Vector2(0, -5), color, 2.0, true)
			draw_line(center, center + Vector2(4, 2), color, 2.0, true)
		"elimination":
			# Crosshair.
			draw_arc(center, 8.0, 0.0, TAU, 24, color, 2.0, true)
			draw_arc(center, 2.0, 0.0, TAU, 12, color, 2.0, true)
			draw_line(center + Vector2(-13, 0), center + Vector2(-7, 0), color, 2.0, true)
			draw_line(center + Vector2(7, 0), center + Vector2(13, 0), color, 2.0, true)
			draw_line(center + Vector2(0, -13), center + Vector2(0, -7), color, 2.0, true)
			draw_line(center + Vector2(0, 7), center + Vector2(0, 13), color, 2.0, true)
		"reward":
			# Coin stack.
			draw_circle(center + Vector2(1, -2), 8.0, Color(0.13, 0.09, 0.02), true)
			draw_arc(center + Vector2(1, -2), 8.0, 0.0, TAU, 24, color, 2.0, true)
			draw_arc(center + Vector2(-3, 4), 7.0, 0.0, TAU, 24, color.darkened(0.15), 2.0, true)
			draw_line(center + Vector2(1, -6), center + Vector2(1, 2), color, 1.5, true)
		_:
			draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), color, false, 2.0)

func get_contract_icon_center_local() -> Vector2:
	var icon := $Margin/Content/Header/ContractIcon as Control
	return icon.get_global_rect().get_center() - get_global_rect().position

func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style
