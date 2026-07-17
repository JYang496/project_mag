extends Control

const OPEN_DURATION := 0.34
const CARD_REVEAL_DURATION := 0.18
const CARD_REVEAL_INTERVAL := 0.07
const CLOSE_DURATION := 0.16
const SHADE_OPACITY := 0.58
const COMPACT_PANEL_HEIGHT := 500.0
const EXPANDED_PANEL_HEIGHT := 690.0
const PANEL_VERTICAL_SAFE_MARGIN := 8.0
const CARD_SCENE := preload("res://UI/scenes/battle_contract_card.tscn")

var _confirmed := Callable()
var _cancelled := Callable()
var _locked := false
var _transition_tween: Tween

@onready var cards: Array[Button] = [$Shade/Panel/Margin/Content/MainCards/CardLeft, $Shade/Panel/Margin/Content/MainCards/CardMiddle, $Shade/Panel/Margin/Content/ExtraContracts/CardRight]
@onready var shade: ColorRect = $Shade
@onready var panel: PanelContainer = $Shade/Panel
@onready var confirm_button: Button = $Shade/Panel/Margin/Content/Actions/Confirm
@onready var title_label: Label = $Shade/Panel/Margin/Content/Title
@onready var subtitle_label: Label = $Shade/Panel/Margin/Content/Subtitle
@onready var cancel_button: Button = $Shade/Panel/Margin/Content/Actions/Cancel
@onready var terminal_status: Label = $Shade/Panel/Margin/Content/TerminalStatus
@onready var actions: HBoxContainer = $Shade/Panel/Margin/Content/Actions
@onready var extra_contracts: VBoxContainer = $Shade/Panel/Margin/Content/ExtraContracts
@onready var main_contracts_label: Label = $Shade/Panel/Margin/Content/MainContractsLabel
@onready var extra_contracts_label: Label = $Shade/Panel/Margin/Content/ExtraContracts/Label

func _ready() -> void:
	visible = false
	for card in cards:
		card.pressed.connect(_on_card_pressed.bind(card))
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(cancel)

func open(options: Array, confirmed: Callable, cancelled: Callable) -> void:
	if visible or options.size() < 2 or options.size() > 3:
		return
	_confirmed = confirmed
	_cancelled = cancelled
	_locked = true
	confirm_button.disabled = true
	title_label.text = LocalizationManager.tr_key("battle_contract.ui.title", "Choose Battle Contract")
	subtitle_label.text = LocalizationManager.tr_key("battle_contract.ui.subtitle", "Decide the victory condition for the next battle")
	cancel_button.text = LocalizationManager.tr_key("battle_contract.ui.cancel", "Back to Prepare")
	confirm_button.text = LocalizationManager.tr_key("battle_contract.ui.confirm", "Launch Selected Contract")
	main_contracts_label.text = LocalizationManager.tr_key("battle_contract.ui.main_contracts", "Main Contracts")
	extra_contracts_label.text = LocalizationManager.tr_key("battle_contract.ui.extra_contracts", "Extra Contract")
	extra_contracts.visible = options.size() == 3
	_apply_panel_size(extra_contracts.visible)
	for index in cards.size():
		if index < options.size():
			cards[index].visible = true
			cards[index].call("setup", options[index])
		else:
			cards[index].visible = false
	_play_open_transition()

func _apply_panel_size(has_extra_contract: bool) -> void:
	var viewport_height := get_viewport_rect().size.y
	var requested_height := EXPANDED_PANEL_HEIGHT if has_extra_contract else COMPACT_PANEL_HEIGHT
	var available_height := maxf(0.0, viewport_height - PANEL_VERTICAL_SAFE_MARGIN * 2.0)
	var resolved_height := minf(requested_height, available_height)
	panel.offset_top = -resolved_height * 0.5
	panel.offset_bottom = resolved_height * 0.5

func cancel() -> bool:
	if not visible or _locked:
		return false
	_locked = true
	_play_close_transition()
	return true

func dismiss() -> void:
	_kill_transition()
	visible = false
	_locked = false
	_clear_callbacks()

func detach_selected_card(target_parent: Control) -> Button:
	if target_parent == null:
		return null
	for card_index in cards.size():
		var card := cards[card_index]
		if card.definition != BattleContractManager.selected_contract:
			continue
		var screen_rect := card.get_global_rect()
		var old_parent := card.get_parent()
		var old_index := card.get_index()
		card.reparent(target_parent, false)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.position = screen_rect.position
		card.size = screen_rect.size
		card.custom_minimum_size = screen_rect.size
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		card.disabled = true
		card.call("set_selected", false, false)
		var replacement := CARD_SCENE.instantiate() as Button
		old_parent.add_child(replacement)
		old_parent.move_child(replacement, old_index)
		replacement.pressed.connect(_on_card_pressed.bind(replacement))
		cards[card_index] = replacement
		return card
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _locked:
		return
	if event.is_action_pressed("ESC") or event.is_action_pressed("CANCEL"):
		if cancel():
			get_viewport().set_input_as_handled()

func _on_card_pressed(card: Button) -> void:
	if _locked:
		return
	if not BattleContractManager.select_contract(card.definition):
		for candidate in cards:
			candidate.call("set_selected", candidate.definition == BattleContractManager.selected_contract)
		return
	for candidate in cards:
		candidate.call("set_selected", candidate == card)
	confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if _locked or confirm_button.disabled:
		return
	_locked = true
	if _confirmed.is_valid():
		_confirmed.call()

func _clear_callbacks() -> void:
	_confirmed = Callable()
	_cancelled = Callable()

func _play_open_transition() -> void:
	_kill_transition()
	visible = true
	shade.color.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.025, 1.0)
	panel.modulate = Color(0.65, 0.9, 1.0, 0.35)
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	actions.modulate.a = 0.0
	terminal_status.text = "TACTICAL LINK // ACQUIRING CONTRACTS"
	for card in cards:
		if not card.visible:
			continue
		card.modulate.a = 0.0

	_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(shade, "color:a", SHADE_OPACITY, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "scale:x", 1.0, OPEN_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(panel, "modulate", Color.WHITE, OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(title_label, "modulate:a", 1.0, 0.16).set_delay(0.16)
	_transition_tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.16).set_delay(0.2)
	for index in cards.size():
		var card := cards[index]
		if not card.visible:
			continue
		var reveal_delay := 0.22 + index * CARD_REVEAL_INTERVAL
		_transition_tween.tween_property(card, "modulate:a", 1.0, CARD_REVEAL_DURATION).set_delay(reveal_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(actions, "modulate:a", 1.0, 0.16).set_delay(0.36)
	_transition_tween.chain().tween_callback(_finish_open_transition).set_delay(0.02)

func _finish_open_transition() -> void:
	_transition_tween = null
	terminal_status.text = "TACTICAL LINK // CONTRACTS READY"
	_locked = false
	cards[0].grab_focus()

func _play_close_transition() -> void:
	_kill_transition()
	terminal_status.text = "TACTICAL LINK // CLOSING"
	_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_transition_tween.tween_property(shade, "color:a", 0.0, CLOSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(panel, "scale:x", 0.025, CLOSE_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(panel, "modulate:a", 0.2, CLOSE_DURATION)
	_transition_tween.chain().tween_callback(_finish_close_transition)

func _finish_close_transition() -> void:
	_transition_tween = null
	visible = false
	_locked = false
	var callback := _cancelled
	_clear_callbacks()
	if callback.is_valid():
		callback.call()

func _kill_transition() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
