extends Button

const BattleContractDefinition = preload("res://Combat/battle_contract/BattleContractDefinition.gd")

var definition: BattleContractDefinition
var _accent_color := Color(0.45, 0.65, 0.85)
var _selected := false

func setup(value: BattleContractDefinition) -> void:
	definition = value
	disabled = false
	modulate = Color.WHITE
	var id := str(definition.contract_id)
	_accent_color = definition.accent_color.lightened(0.25)
	$Margin/Content/Title.text = LocalizationManager.tr_key(definition.name_key, id.capitalize())
	$Margin/Content/Description.text = LocalizationManager.tr_key("battle_contract.card.%s.summary" % id, "Complete the contract objective.")
	$Margin/Content/Reward.text = LocalizationManager.tr_key("battle_contract.card.%s.reward_hint" % id, "")
	_apply_card_styles()
	set_selected(false, false)

func setup_reward_unavailable() -> void:
	definition = null
	button_pressed = false
	disabled = true
	_selected = false
	$Margin/Content/Title.text = LocalizationManager.tr_key("battle_contract.ui.reward_slot.title", "Reward Slot")
	$Margin/Content/Description.text = LocalizationManager.tr_key("battle_contract.ui.reward_slot.summary", "Not available this round (25% chance each round)")
	$Margin/Content/Reward.text = ""
	$SelectedBadge.visible = false
	self_modulate = Color.WHITE
	modulate = Color(0.42, 0.46, 0.50, 0.62)

func set_selected(value: bool, dim_unselected: bool = true) -> void:
	_selected = value
	button_pressed = value
	$SelectedBadge.visible = value
	self_modulate = Color.WHITE if value or not dim_unselected else Color(0.72, 0.72, 0.72, 0.82)

func _apply_card_styles() -> void:
	add_theme_stylebox_override("normal", _make_style(_accent_color.darkened(0.82), _accent_color.darkened(0.35), 1))
	add_theme_stylebox_override("hover", _make_style(_accent_color.darkened(0.72), _accent_color.lightened(0.08), 2))
	add_theme_stylebox_override("pressed", _make_style(_accent_color.darkened(0.58), _accent_color.lightened(0.18), 4))

	# Focus only identifies the keyboard/controller cursor. Selection is communicated
	# separately by the stronger pressed style and the check badge.
	var focus_style := _make_style(Color(0, 0, 0, 0), Color(0.82, 0.88, 0.94, 0.72), 1)
	focus_style.expand_margin_left = 3.0
	focus_style.expand_margin_top = 3.0
	focus_style.expand_margin_right = 3.0
	focus_style.expand_margin_bottom = 3.0
	add_theme_stylebox_override("focus", focus_style)

func _make_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style
