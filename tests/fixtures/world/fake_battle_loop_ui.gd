extends UI

var received_options: Array = []
var confirm_callback: Callable
var selection_closed := false
var intro_prepared := false
var battle_intro_played := false
var purchase_refresh_reset := false
var reward_summary_requests := 0
var standard_reward_requests := 0

func request_battle_contract_selection(options: Array, confirm: Callable, _cancel: Callable) -> void:
	received_options = options.duplicate()
	confirm_callback = confirm

func prepare_battle_contract_intro() -> void:
	intro_prepared = true

func close_battle_contract_selection() -> void:
	selection_closed = true

func play_battle_entry_intro(_is_boss: bool = false) -> void:
	battle_intro_played = true

func reset_purchase_refresh_cost() -> void:
	purchase_refresh_reset = true

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
	_show_draft_hint: bool = false
) -> bool:
	standard_reward_requests += 1
	return true
