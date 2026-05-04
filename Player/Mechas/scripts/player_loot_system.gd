extends RefCounted
class_name PlayerLootSystem

var _player
var _auto_loot_running: bool = false

func setup(player) -> void:
	_player = player

func on_collect_area_entered(area) -> void:
	if _player == null:
		return
	if area.is_in_group("collectables") and area is Coin:
		var value: int = area.collect()
		value = _player.apply_loot_bonus(value, &"coin")
		_player.PlayerData.player_gold += value
		_player.PlayerData.round_coin_collected += value
		_player.PlayerData.run_gold_earned += value
		_player.coin_collected.emit()

func on_collect_chip_area_entered(area) -> void:
	if _player == null:
		return
	if area.is_in_group("collectables") and area is Chip:
		var value: int = area.collect()
		value = _player.apply_loot_bonus(value, &"chip")
		_player.PlayerData.player_exp += value
		_player.PlayerData.round_chip_collected += value

func on_grab_area_entered(area) -> void:
	if _player == null:
		return
	if area.is_in_group("collectables"):
		if area is Coin:
			area.target = _player.collect_area
		elif area is Chip:
			area.target = _player

func on_phase_changed(new_phase: String, previous_phase: String) -> void:
	if _player == null:
		return
	if new_phase == PhaseManager.PREPARE and previous_phase == PhaseManager.BATTLE:
		run_battle_end_auto_collect()
		return
	if new_phase == PhaseManager.BATTLE and _auto_loot_running:
		_auto_loot_running = false
		restore_collect_ranges_after_auto_loot()

func run_battle_end_auto_collect() -> void:
	if _player == null or _auto_loot_running:
		return
	_auto_loot_running = true
	expand_collect_ranges_for_auto_loot()
	var elapsed := 0.0
	while elapsed < _player.AUTO_LOOT_DURATION_SEC and _auto_loot_running and _player.is_inside_tree():
		process_auto_loot_grab_overlaps()
		await _player.get_tree().create_timer(_player.AUTO_LOOT_TICK_SEC).timeout
		elapsed += _player.AUTO_LOOT_TICK_SEC
	restore_collect_ranges_after_auto_loot()
	_auto_loot_running = false

func attract_all_coins() -> void:
	if _player == null or not _player.collect_area:
		return
	for collectable in _player.get_tree().get_nodes_in_group("collectables"):
		if not is_instance_valid(collectable):
			continue
		if collectable is Coin:
			collectable.target = _player.collect_area
		elif collectable is Chip:
			collectable.target = _player

func expand_collect_ranges_for_auto_loot() -> void:
	var grab_circle := _player.grab_radius.shape as CircleShape2D
	if grab_circle:
		grab_circle.radius = _player.AUTO_LOOT_GRAB_RADIUS

func restore_collect_ranges_after_auto_loot() -> void:
	if _player == null:
		return
	_player.update_grab_radius()

func process_auto_loot_grab_overlaps() -> void:
	if _player == null or _player.grab_area == null:
		return
	for area in _player.grab_area.get_overlapping_areas():
		on_grab_area_entered(area)
