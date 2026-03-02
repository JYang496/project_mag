extends CellAuraModule
class_name RegenAuraModule

@export var heal_interval_sec: float = 5.0
@export var heal_amount: int = 1

var _heal_timer: Timer

func _ready() -> void:
	super._ready()
	_heal_timer = Timer.new()
	_heal_timer.one_shot = false
	_heal_timer.wait_time = maxf(0.1, heal_interval_sec)
	add_child(_heal_timer)
	_heal_timer.timeout.connect(_on_heal_timer_timeout)

func _apply_aura_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if _heal_timer and _heal_timer.is_stopped():
		_heal_timer.start()

func _remove_aura_from_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if _inside_players.is_empty() and _heal_timer:
		_heal_timer.stop()

func _clear_all_players() -> void:
	super._clear_all_players()
	if _heal_timer:
		_heal_timer.stop()

func set_aura_parameters(params: Dictionary) -> void:
	if params.has("aura_regen_interval_sec"):
		heal_interval_sec = maxf(0.1, float(params["aura_regen_interval_sec"]))
	if params.has("aura_regen_heal_amount"):
		heal_amount = max(0, int(params["aura_regen_heal_amount"]))
	if _heal_timer:
		_heal_timer.wait_time = heal_interval_sec

func _on_heal_timer_timeout() -> void:
	if not _is_active_phase():
		return
	if heal_amount <= 0:
		return
	if _inside_players.is_empty():
		if _heal_timer:
			_heal_timer.stop()
		return
	for player in _inside_players:
		if not is_instance_valid(player):
			continue
		if player != PlayerData.player:
			continue
		PlayerData.player_hp = min(PlayerData.player_hp + heal_amount, PlayerData.player_max_hp)
