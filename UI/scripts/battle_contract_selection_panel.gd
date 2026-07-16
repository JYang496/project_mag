extends Control

var _confirmed := Callable()
var _cancelled := Callable()
var _locked := false

@onready var cards: Array[Button] = [$Shade/Panel/Margin/Content/Cards/CardLeft, $Shade/Panel/Margin/Content/Cards/CardMiddle, $Shade/Panel/Margin/Content/Cards/CardRight]
@onready var confirm_button: Button = $Shade/Panel/Margin/Content/Actions/Confirm
@onready var title_label: Label = $Shade/Panel/Margin/Content/Title
@onready var subtitle_label: Label = $Shade/Panel/Margin/Content/Subtitle
@onready var cancel_button: Button = $Shade/Panel/Margin/Content/Actions/Cancel

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
	_locked = false
	confirm_button.disabled = true
	title_label.text = LocalizationManager.tr_key("battle_contract.ui.title", "Choose Battle Contract")
	subtitle_label.text = LocalizationManager.tr_key("battle_contract.ui.subtitle", "Decide the victory condition for the next battle")
	cancel_button.text = LocalizationManager.tr_key("battle_contract.ui.cancel", "Back to Prepare")
	confirm_button.text = LocalizationManager.tr_key("battle_contract.ui.confirm", "Launch Selected Contract")
	for index in cards.size():
		cards[index].button_pressed = false
		if index < options.size():
			cards[index].call("setup", options[index])
		else:
			cards[index].call("setup_reward_unavailable")
	visible = true
	cards[0].grab_focus()

func cancel() -> bool:
	if not visible or _locked:
		return false
	visible = false
	var callback := _cancelled
	_clear_callbacks()
	if callback.is_valid():
		callback.call()
	return true

func dismiss() -> void:
	visible = false
	_locked = false
	_clear_callbacks()

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
			candidate.button_pressed = candidate.definition == BattleContractManager.selected_contract
		return
	for candidate in cards:
		candidate.button_pressed = candidate == card
	confirm_button.disabled = false
	confirm_button.grab_focus()

func _on_confirm_pressed() -> void:
	if _locked or confirm_button.disabled:
		return
	_locked = true
	if _confirmed.is_valid():
		_confirmed.call()

func _clear_callbacks() -> void:
	_confirmed = Callable()
	_cancelled = Callable()
