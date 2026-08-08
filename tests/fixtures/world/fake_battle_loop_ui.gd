extends UI

signal battle_intro_released

var received_options: Array = []
var confirm_callback: Callable
var selection_closed := false
var intro_prepared := false
var entry_transition_prepared := false
var battle_intro_played := false
var rest_entry_prepared := false
var rest_intro_played := false
var hold_battle_intro := false
var purchase_refresh_reset := false
var reward_summary_requests := 0
var standard_reward_requests := 0
var standard_reward_options: Array[RewardInfo] = []
var standard_reward_confirm: Callable

func request_battle_contract_selection(options: Array, confirm: Callable, _cancel: Callable) -> void:
	received_options = options.duplicate()
	confirm_callback = confirm

func prepare_battle_contract_intro() -> void:
	intro_prepared = true

func prepare_battle_entry_transition() -> void:
	entry_transition_prepared = true

func close_battle_contract_selection() -> void:
	selection_closed = true

func play_battle_entry_intro(_is_boss: bool = false) -> void:
	battle_intro_played = true
	if hold_battle_intro:
		await battle_intro_released

func prepare_rest_area_entry_transition() -> void:
	rest_entry_prepared = true

func play_rest_area_entry_intro() -> void:
	rest_intro_played = true

func reset_purchase_refresh_cost() -> void:
	purchase_refresh_reset = true

func show_item_message(_text: String, _duration: float = 1.8) -> void:
	pass

func request_weapon_replacement(
	weapon: Weapon,
	_allow_cancel: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	var result := InventoryData.store_weapon(weapon)
	if on_complete.is_valid():
		on_complete.call_deferred(bool(result.get("ok", false)), result)
	return bool(result.get("ok", false))

func request_task_reward_summary(_rewards: Array[RewardInfo], closed: Callable) -> bool:
	reward_summary_requests += 1
	if closed.is_valid():
		closed.call_deferred()
	return true

func request_reward_selection(
	_route_display_name: String,
	_reward_options: Array[RewardInfo],
	_on_confirm: Callable = Callable(),
	_on_cancel: Callable = Callable(),
	_allow_cancel: bool = true,
	_show_draft_hint: bool = false,
	_presentation_mode: StringName = &"standard"
) -> bool:
	standard_reward_requests += 1
	standard_reward_options = _reward_options.duplicate()
	standard_reward_confirm = _on_confirm
	return true
