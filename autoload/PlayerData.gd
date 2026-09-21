extends Node

signal main_weapon_index_changed(old_index: int, new_index: int, step: int)
signal weapon_list_changed()
signal player_health_changed(current_hp: int, max_hp: int)
signal player_damage_received(feedback: Dictionary)
signal player_gold_changed(value: int)
signal modification_points_changed(value: int)
signal gold_supply_changed()
signal gold_supply_reset()

const MAX_PLAYER_LEVEL := 10

@onready var player = null
var select_mecha_id :int = 1

var player_level := 1 :
	get:
		return player_level
	set(value):
		player_level = clampi(int(value), 1, MAX_PLAYER_LEVEL)
		next_level_exp = int(GlobalVariables.mech_data["next_level_exp"][player_level - 1]) if GlobalVariables.mech_data else 10
		if player_level >= MAX_PLAYER_LEVEL:
			player_exp = 0

var next_level_exp := 10 :
	get:
		return next_level_exp
	set(value):
		next_level_exp = clampi(int(value), 10, 99999)

var player_exp := 0 :
	get:
		return player_exp
	set(value):
		var remaining_exp := clampi(int(value), 0, 99999)
		while player_level < MAX_PLAYER_LEVEL and remaining_exp >= next_level_exp:
			var required_exp := next_level_exp
			remaining_exp -= required_exp
			player_level += 1
		player_exp = 0 if player_level >= MAX_PLAYER_LEVEL else remaining_exp
		
var player_speed : float = 120.0 :
	get:
		return player_speed
	set(value):
		player_speed = clampf(float(value), 1.0, 1000.0)
var player_bonus_speed : float = 0.0
var dash_cooldown: float = 5.0
var active_skill_cooldown_multiplier: float = 1.0

var player_max_hp := 5 :
	get:
		return player_max_hp
	set(value):
		var next_max := clampi(int(value), 1, 999)
		if player_max_hp == next_max:
			return
		player_max_hp = next_max
		if player_hp > player_max_hp:
			player_hp = player_max_hp
		player_health_changed.emit(player_hp, player_max_hp)
var player_hp := player_max_hp :
	get:
		return player_hp
	set(value):
		var next_hp := clampi(int(value), 0, player_max_hp)
		if player_hp == next_hp:
			return
		player_hp = next_hp
		player_health_changed.emit(player_hp, player_max_hp)

var hp_regen := 0
var hp_bonus_regen := 0
var hp_total_regen := hp_regen + hp_bonus_regen

var armor := 0
var bonus_armor := 0
var total_armor := armor + bonus_armor

var shield := 0 :
	get:
		return shield
	set(value):
		shield = clampi(int(value),0, player_max_hp)
var bonus_shield := 0
var total_shield := shield + bonus_shield

var damage_reduction := 1.0 :
	get:
		return damage_reduction
	set(value):
		damage_reduction = clampf(float(value), 0.2, 5.0)
var bonus_damage_reduction := 1.0
var total_damage_reduction := damage_reduction * bonus_damage_reduction

var hurt_cd := 3.0 :
	get:
		return hurt_cd
	set(value):
		hurt_cd = clampf(float(value), 0.2, 5.0)

var collision_cd := 1.0 :
	get:
		return collision_cd
	set(value):
		collision_cd = clampf(float(value), 0.2, 5.0)

var crit_rate := 0.0 :
	get:
		return crit_rate
	set(value):
		crit_rate = clampf(float(value), 0.0, 1.0)
var bonus_crit_rate := 0.0
var total_crit_rate: float:
	get:
		return clampf(float(crit_rate) + float(bonus_crit_rate), 0.0, 1.0)

var crit_damage := 1.0
var bonus_crit_damage := 1.0
var total_crit_damage: float:
	get:
		return maxf(1.0, float(crit_damage) * float(bonus_crit_damage))

var grab_radius := 50.0 :
	get:
		return grab_radius
	set(value):
		grab_radius = clampf(float(value),0.0, 1200.0)
		total_grab_radius = grab_radius * grab_radius_mutifactor
var grab_radius_mutifactor := 1.0 :
	get:
		return grab_radius_mutifactor
	set(value):
		grab_radius_mutifactor = value
		total_grab_radius = grab_radius * grab_radius_mutifactor

var total_grab_radius := grab_radius * grab_radius_mutifactor

var player_gold := 0 :
	get:
		return player_gold
	set(value):
		var next_gold := int(value)
		if player_gold == next_gold:
			return
		player_gold = next_gold
		player_gold_changed.emit(player_gold)
var round_coin_collected := 0
var round_chip_collected := 0
var run_total_damage_dealt := 0
var run_enemy_kills := 0
var run_elite_kills := 0
var run_completed_levels := 0
var run_gold_earned := 0
var run_gold_recycled := 0
var run_gold_spent := 0
var rounds_without_weapon_progress := 0
var weapon_progress_this_battle := false
var testing_keep_hp_above_zero := false
var is_interacting : bool = false

# Run-local service currency is separate from gold and supply progress.
var modification_points: int = 0:
	set(value):
		var next_value := maxi(value, 0)
		if modification_points == next_value:
			return
		modification_points = next_value
		modification_points_changed.emit(modification_points)
var _last_modification_rest_level: int = -1

func get_modification_upgrade_cost(item_type: StringName) -> int:
	var economy: EconomyConfig = GlobalVariables.economy_data if GlobalVariables.economy_data else EconomyConfig.new()
	return maxi(economy.module_upgrade_modification_cost if item_type == &"module" else economy.weapon_upgrade_modification_cost, 1)

func grant_rest_modification_points() -> int:
	if not PhaseManager.is_rest_phase() or PhaseManager.current_level <= _last_modification_rest_level:
		return 0
	_last_modification_rest_level = PhaseManager.current_level
	var economy: EconomyConfig = GlobalVariables.economy_data if GlobalVariables.economy_data else EconomyConfig.new()
	var amount := maxi(economy.modification_points_per_rest, 0)
	modification_points += amount
	return amount

func spend_modification_points(amount: int) -> bool:
	if not PhaseManager.can_configure_loadout() or amount <= 0 or modification_points < amount:
		return false
	modification_points -= amount
	return true

func export_modification_state() -> Dictionary:
	return {"balance": modification_points, "last_rest_level": _last_modification_rest_level}

func import_modification_state(payload: Dictionary) -> void:
	modification_points = maxi(int(payload.get("balance", 0)), 0)
	_last_modification_rest_level = maxi(int(payload.get("last_rest_level", -1)), -1)

# Run-local supply data is separate from the legacy spendable balance.
var gold_supply_enabled := false
var gold_supply_progress: int = 0
var gold_supply_level: int = 0
var gold_supply_progress_spent: int = 0
var _pending_gold_supplies: Array[Dictionary] = []
var _gold_supply_rules: Dictionary = {}
var _claimed_gold_supplies: Array[Dictionary] = []
var gold_supply_rewards = preload("res://World/rewards/gold_supply_reward_service.gd").new()

func get_pending_gold_supplies() -> Array[Dictionary]:
	return _pending_gold_supplies.duplicate(true)

func get_pending_gold_supply_count() -> int:
	return _pending_gold_supplies.size()

func get_next_pending_gold_supply_sequence() -> int:
	return int(_pending_gold_supplies[0].sequence) if not _pending_gold_supplies.is_empty() else 0

func get_claimed_gold_supplies() -> Array[Dictionary]:
	return _claimed_gold_supplies.duplicate(true)

# Internal ledger access for the supply service; callers receive copies above.
func _find_gold_supply_record(sequence: int) -> Dictionary:
	for record in _pending_gold_supplies:
		if int(record.get("sequence", 0)) == sequence:
			return record
	return {}

func _finish_gold_supply_claim(sequence: int, receipt: Dictionary) -> void:
	var record := _find_gold_supply_record(sequence)
	_pending_gold_supplies.erase(record)
	_claimed_gold_supplies.append(receipt.duplicate(true))

func get_next_gold_supply_threshold() -> int:
	var thresholds: Array = _gold_supply_rules.get("thresholds", [])
	if gold_supply_level < thresholds.size():
		return maxi(int(thresholds[gold_supply_level]), 0)
	if thresholds.is_empty() or not PhaseManager.endless_mode \
			or not bool(_gold_supply_rules.get("endless_enabled", false)):
		return 0 # Exhausted: retain overflow, never repeat the last threshold.
	var tail_index: int = gold_supply_level - thresholds.size() + 1
	var increment: int = maxi(int(_gold_supply_rules.get("endless_first_increment", 24)), 1)
	var growth: int = maxi(int(_gold_supply_rules.get("endless_increment_growth", 2)), 0)
	return int(thresholds[-1]) + tail_index * increment + int(tail_index * (tail_index - 1) / 2) * growth

func _route_gold_income(amount: int) -> void:
	if not gold_supply_enabled:
		player_gold += amount
		return
	gold_supply_progress += amount
	var threshold := get_next_gold_supply_threshold()
	while threshold > 0 and gold_supply_progress >= threshold:
		gold_supply_progress -= threshold
		gold_supply_progress_spent += threshold
		gold_supply_level += 1
		var qualities: Array = _gold_supply_rules.get("qualities", [])
		var quality := "common"
		if not qualities.is_empty():
			quality = str(qualities[mini(gold_supply_level - 1, qualities.size() - 1)])
		_pending_gold_supplies.append({"source": "gold_supply", "sequence": gold_supply_level, "quality": quality, "threshold": threshold, "status": "unprepared"})
		threshold = get_next_gold_supply_threshold()
	gold_supply_changed.emit()

func _reset_gold_supply_state(use_configured_mode: bool) -> void:
	gold_supply_reset.emit()
	# New-game reset precedes world preparation, so load the economy switch first.
	if use_configured_mode and GlobalVariables.economy_data == null:
		DataHandler.prepare_economy_data()
	var economy := GlobalVariables.economy_data if GlobalVariables.economy_data else EconomyConfig.new()
	gold_supply_enabled = use_configured_mode and economy.gold_supply_enabled
	gold_supply_progress = 0
	gold_supply_level = 0
	gold_supply_progress_spent = 0
	_pending_gold_supplies.clear()
	_claimed_gold_supplies.clear()
	_gold_supply_rules = economy.build_gold_supply_rules() if gold_supply_enabled else {}
	gold_supply_changed.emit()

func export_gold_supply_state() -> Dictionary:
	if not gold_supply_enabled:
		return {}
	return {
		"schema_version": 1,
		"enabled": true,
		"progress": gold_supply_progress,
		"level": gold_supply_level,
		"progress_spent": gold_supply_progress_spent,
		"pending": _pending_gold_supplies.duplicate(true),
		"claimed": _claimed_gold_supplies.duplicate(true),
		"rules": _gold_supply_rules.duplicate(true),
	}

func import_gold_supply_state(payload: Dictionary) -> void:
	# Missing data means a legacy run, regardless of the new-run config switch.
	_reset_gold_supply_state(false)
	if int(payload.get("schema_version", 0)) != 1 or not bool(payload.get("enabled", false)):
		return
	gold_supply_enabled = true
	gold_supply_progress = maxi(int(payload.get("progress", 0)), 0)
	gold_supply_level = maxi(int(payload.get("level", 0)), 0)
	gold_supply_progress_spent = maxi(int(payload.get("progress_spent", 0)), 0)
	_gold_supply_rules = (payload.get("rules", {}) as Dictionary).duplicate(true)
	# JSON numbers load as floats; normalize counters/rules for deterministic snapshots.
	var thresholds: Array = []
	for value in _gold_supply_rules.get("thresholds", []):
		thresholds.append(int(value))
	_gold_supply_rules["thresholds"] = thresholds
	_gold_supply_rules["endless_first_increment"] = maxi(int(_gold_supply_rules.get("endless_first_increment", 24)), 1)
	_gold_supply_rules["endless_increment_growth"] = maxi(int(_gold_supply_rules.get("endless_increment_growth", 2)), 0)
	for record in payload.get("pending", []):
		if record is Dictionary:
			var restored_record := (record as Dictionary).duplicate(true)
			restored_record["sequence"] = int(restored_record.get("sequence", 0))
			restored_record["threshold"] = int(restored_record.get("threshold", 0))
			restored_record = gold_supply_rewards.normalize_record(restored_record)
			_pending_gold_supplies.append(restored_record)
	for receipt in payload.get("claimed", []):
		if receipt is Dictionary:
			var restored_receipt := (receipt as Dictionary).duplicate(true)
			restored_receipt["sequence"] = int(restored_receipt.get("sequence", 0))
			restored_receipt["selected"] = int(restored_receipt.get("selected", 0))
			_claimed_gold_supplies.append(restored_receipt)
	# Restoration is not income and must not generate supplies again.
	gold_supply_changed.emit()

func earn_gold(amount: int, count_as_collected_coin: bool = false) -> int:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return 0
	run_gold_earned += safe_amount
	if count_as_collected_coin:
		round_coin_collected += safe_amount
	_route_gold_income(safe_amount)
	return safe_amount

func recycle_gold(amount: int) -> int:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return 0
	run_gold_recycled += safe_amount
	_route_gold_income(safe_amount)
	return safe_amount

func spend_gold(amount: int) -> bool:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return true
	if gold_supply_enabled:
		return false
	if player_gold < safe_amount:
		return false
	player_gold -= safe_amount
	run_gold_spent += safe_amount
	return true

func refund_gold_spending(amount: int) -> int:
	if gold_supply_enabled:
		return 0
	var safe_amount := clampi(amount, 0, run_gold_spent)
	if safe_amount <= 0:
		return 0
	player_gold += safe_amount
	run_gold_spent -= safe_amount
	return safe_amount

func record_battle_without_weapon_progress() -> void:
	rounds_without_weapon_progress += 1

func record_weapon_progress() -> void:
	rounds_without_weapon_progress = 0
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		weapon_progress_this_battle = true

var detected_enemies : Array = []
var cloestest_enemy : Area2D = null

var player_weapon_list = []
var max_weapon_num : int = 4
var main_weapon_index: int = -1
var on_select_weapon : int = -1 :
	get:
		return on_select_weapon
	set(value):
		if value >= player_weapon_list.size() or player_weapon_list.size() <= 0:
			value = -1
		if value < -1:
			value = player_weapon_list.size() - 1
		on_select_weapon = clampi(value,-1,player_weapon_list.size() - 1)
		if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
			GlobalVariables.ui.refresh_border()

var player_companion_lsit = []
var player_augment_list = []

func set_hp_safety_for_testing(enabled: bool) -> void:
	testing_keep_hp_above_zero = enabled
	if testing_keep_hp_above_zero:
		if player_max_hp < 1:
			player_max_hp = 1
		if player_hp < 1:
			player_hp = 1


func reset_runtime_state() -> void:
	var prev_main_index := main_weapon_index
	player = null
	player_level = 1
	next_level_exp = 10
	player_exp = 0
	player_speed = 120.0
	player_bonus_speed = 0.0
	dash_cooldown = 5.0
	active_skill_cooldown_multiplier = 1.0
	player_max_hp = 5
	player_hp = 5
	hp_regen = 0
	hp_bonus_regen = 0
	hp_total_regen = 0
	armor = 0
	bonus_armor = 0
	total_armor = 0
	shield = 0
	bonus_shield = 0
	total_shield = 0
	damage_reduction = 1.0
	bonus_damage_reduction = 1.0
	total_damage_reduction = 1.0
	hurt_cd = 3.0
	collision_cd = 1.0
	crit_rate = 0.0
	bonus_crit_rate = 0.0
	crit_damage = 1.0
	bonus_crit_damage = 1.0
	grab_radius = 50.0
	grab_radius_mutifactor = 1.0
	total_grab_radius = 50.0
	_reset_gold_supply_state(true)
	modification_points = 0
	_last_modification_rest_level = -1
	# Supply runs start at zero; the legacy 10-gold gift is not supply income.
	player_gold = 0 if gold_supply_enabled else _get_default_player_gold()
	round_coin_collected = 0
	round_chip_collected = 0
	run_total_damage_dealt = 0
	run_enemy_kills = 0
	run_elite_kills = 0
	run_completed_levels = 0
	run_gold_earned = 0
	run_gold_recycled = 0
	run_gold_spent = 0
	rounds_without_weapon_progress = 0
	weapon_progress_this_battle = false
	is_interacting = false
	detected_enemies.clear()
	cloestest_enemy = null
	player_weapon_list.clear()
	max_weapon_num = 4
	main_weapon_index = -1
	on_select_weapon = -1
	player_companion_lsit.clear()
	player_augment_list.clear()
	testing_keep_hp_above_zero = false
	weapon_list_changed.emit()
	if prev_main_index != main_weapon_index:
		main_weapon_index_changed.emit(prev_main_index, main_weapon_index, 0)

func _get_default_player_gold() -> int:
	if GlobalVariables.economy_data:
		return GlobalVariables.economy_data.get_default_player_gold()
	return EconomyConfig.new().get_default_player_gold()

func sanitize_main_weapon_index() -> void:
	var old_index := main_weapon_index
	if player_weapon_list.is_empty():
		main_weapon_index = -1
	else:
		main_weapon_index = clampi(main_weapon_index, 0, player_weapon_list.size() - 1)
	if old_index != main_weapon_index:
		main_weapon_index_changed.emit(old_index, main_weapon_index, 0)

func clear_weapon_runtime_references() -> void:
	var old_main_index := main_weapon_index
	player_weapon_list.clear()
	main_weapon_index = -1
	on_select_weapon = -1
	weapon_list_changed.emit()
	if old_main_index != main_weapon_index:
		main_weapon_index_changed.emit(old_main_index, main_weapon_index, 0)

func can_switch_main_weapon() -> bool:
	return player_weapon_list.size() > 1

func set_main_weapon_index(value: int) -> void:
	var old_index := main_weapon_index
	if player_weapon_list.is_empty():
		main_weapon_index = -1
	else:
		main_weapon_index = clampi(value, 0, player_weapon_list.size() - 1)
	if old_index != main_weapon_index:
		var step_sign := _calculate_step_sign(old_index, main_weapon_index, player_weapon_list.size())
		main_weapon_index_changed.emit(old_index, main_weapon_index, step_sign)
	on_select_weapon = main_weapon_index
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.refresh_border()

func shift_main_weapon(step: int) -> bool:
	_sanitize_weapon_list_for_switch()
	if not can_switch_main_weapon():
		sanitize_main_weapon_index()
		on_select_weapon = main_weapon_index
		return false
	if main_weapon_index < 0:
		main_weapon_index = 0
	if step == 0:
		on_select_weapon = main_weapon_index
		return false
	var size := player_weapon_list.size()
	var original_index := main_weapon_index
	var next := original_index
	for i in range(size - 1):
		next = (next + step) % size
		if next < 0:
			next += size
		var candidate := player_weapon_list[next] as Weapon
		if candidate == null or not is_instance_valid(candidate):
			continue
		set_main_weapon_index(next)
		return main_weapon_index != original_index
	on_select_weapon = main_weapon_index
	if GlobalVariables.ui and is_instance_valid(GlobalVariables.ui):
		GlobalVariables.ui.refresh_border()
	return false

func _sanitize_weapon_list_for_switch() -> void:
	var current_main: Weapon = null
	if main_weapon_index >= 0 and main_weapon_index < player_weapon_list.size():
		var current_main_ref: Variant = player_weapon_list[main_weapon_index]
		if is_instance_valid(current_main_ref):
			current_main = current_main_ref as Weapon
	var valid_weapons: Array = []
	for weapon_variant in player_weapon_list:
		if not is_instance_valid(weapon_variant):
			continue
		var weapon := weapon_variant as Weapon
		if weapon != null:
			valid_weapons.append(weapon)
	if valid_weapons.size() == player_weapon_list.size():
		return
	player_weapon_list = valid_weapons
	if current_main != null and is_instance_valid(current_main):
		main_weapon_index = player_weapon_list.find(current_main)
	else:
		main_weapon_index = clampi(main_weapon_index, -1, player_weapon_list.size() - 1)
	on_select_weapon = main_weapon_index
	weapon_list_changed.emit()

func _is_auto_fire_weapon(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.has_method("has_weapon_trait"):
		return false
	return bool(weapon.call("has_weapon_trait", WeaponTrait.AUTO_FIRE))

func notify_weapon_list_changed() -> void:
	weapon_list_changed.emit()

func _calculate_step_sign(old_index: int, new_index: int, list_size: int) -> int:
	if list_size <= 1 or old_index < 0 or new_index < 0:
		return 0
	var diff := new_index - old_index
	if diff == 0:
		return 0
	var abs_diff := absi(diff)
	if abs_diff > floori(float(list_size) / 2.0):
		return -1 if diff > 0 else 1
	return 1 if diff > 0 else -1
