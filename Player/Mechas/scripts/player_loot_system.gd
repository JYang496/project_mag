extends RefCounted
class_name PlayerLootSystem

var _player

func setup(player) -> void:
	_player = player

func on_collect_area_entered(area) -> void:
	if _player == null:
		return
	if area.is_in_group("collectables") and area is Coin:
		var denomination := int(area.value)
		var value: int = area.collect()
		if value <= 0:
			return
		if not area.contract_reward:
			value = _player.apply_loot_bonus(value, &"coin")
		_player.PlayerData.earn_gold(value, not area.contract_reward)
		if denomination >= 5 and _player.has_method("_spawn_player_floating_hint"):
			_player.call("_spawn_player_floating_hint", "+%d" % denomination)
		if not area.contract_reward and GlobalVariables.enemy_spawner and is_instance_valid(GlobalVariables.enemy_spawner) and GlobalVariables.enemy_spawner.has_method("record_kill_gold_coin_collected"):
			GlobalVariables.enemy_spawner.record_kill_gold_coin_collected(value)
		if not area.contract_reward:
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
