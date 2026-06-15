extends Module

enum PlayerStat {
	CRIT_RATE,
	CRIT_DAMAGE,
	DASH_COOLDOWN,
	GRAB_RADIUS,
}

@export var item_name: String = "Player Stat"
@export var player_stat: PlayerStat = PlayerStat.CRIT_RATE
@export var value_lv1: float = 0.0
@export var value_lv2: float = 0.0
@export var value_lv3: float = 0.0

var _applied_value: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	_connect_player_data_signals()
	call_deferred("_refresh_player_stat")

func _ready() -> void:
	_refresh_player_stat()

func _exit_tree() -> void:
	_disconnect_player_data_signals()
	_remove_player_stat()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		call_deferred("_refresh_player_stat")

func set_module_level(new_level: int) -> void:
	super.set_module_level(new_level)
	_refresh_player_stat()

func get_module_display_name() -> String:
	return item_name if item_name != "" else super.get_module_display_name()

func _refresh_player_stat() -> void:
	if not is_inside_tree():
		return
	var target_value := _get_level_value() if _is_equipped_to_main_weapon() else 0.0
	if is_equal_approx(target_value, _applied_value):
		return
	_apply_value_change(_applied_value, target_value)
	_applied_value = target_value

func _remove_player_stat() -> void:
	if is_zero_approx(_applied_value):
		return
	_apply_value_change(_applied_value, 0.0)
	_applied_value = 0.0

func _apply_value_change(previous_value: float, next_value: float) -> void:
	match player_stat:
		PlayerStat.CRIT_RATE:
			PlayerData.bonus_crit_rate = maxf(
				0.0,
				float(PlayerData.bonus_crit_rate) + next_value - previous_value
			)
		PlayerStat.CRIT_DAMAGE:
			PlayerData.bonus_crit_damage = maxf(
				1.0,
				float(PlayerData.bonus_crit_damage) + next_value - previous_value
			)
		PlayerStat.DASH_COOLDOWN:
			var previous_multiplier := maxf(1.0 - previous_value, 0.05)
			var next_multiplier := maxf(1.0 - next_value, 0.05)
			PlayerData.dash_cooldown = maxf(
				0.05,
				float(PlayerData.dash_cooldown) / previous_multiplier * next_multiplier
			)
		PlayerStat.GRAB_RADIUS:
			var previous_multiplier := maxf(1.0 + previous_value, 0.05)
			var next_multiplier := maxf(1.0 + next_value, 0.05)
			PlayerData.grab_radius = maxf(
				0.0,
				float(PlayerData.grab_radius) / previous_multiplier * next_multiplier
			)
			_refresh_player_grab_radius()

func _get_level_value() -> float:
	return maxf(
		0.0,
		WeaponModuleRuntimeUtils.get_value_by_level(
			module_level,
			value_lv1,
			value_lv2,
			value_lv3
		)
	)

func _is_equipped_to_main_weapon() -> bool:
	var owner_weapon := _resolve_weapon()
	if owner_weapon == null or owner_weapon.modules != get_parent():
		return false
	var main_index := int(PlayerData.main_weapon_index)
	if main_index < 0 or main_index >= PlayerData.player_weapon_list.size():
		return false
	return PlayerData.player_weapon_list[main_index] == owner_weapon

func _connect_player_data_signals() -> void:
	var main_changed := Callable(self, "_on_main_weapon_index_changed")
	if not PlayerData.main_weapon_index_changed.is_connected(main_changed):
		PlayerData.main_weapon_index_changed.connect(main_changed)
	var list_changed := Callable(self, "_on_weapon_list_changed")
	if not PlayerData.weapon_list_changed.is_connected(list_changed):
		PlayerData.weapon_list_changed.connect(list_changed)

func _disconnect_player_data_signals() -> void:
	var main_changed := Callable(self, "_on_main_weapon_index_changed")
	if PlayerData.main_weapon_index_changed.is_connected(main_changed):
		PlayerData.main_weapon_index_changed.disconnect(main_changed)
	var list_changed := Callable(self, "_on_weapon_list_changed")
	if PlayerData.weapon_list_changed.is_connected(list_changed):
		PlayerData.weapon_list_changed.disconnect(list_changed)

func _on_main_weapon_index_changed(_old_index: int, _new_index: int, _step: int) -> void:
	_refresh_player_stat()

func _on_weapon_list_changed() -> void:
	_refresh_player_stat()

func _refresh_player_grab_radius() -> void:
	if PlayerData.player != null \
			and is_instance_valid(PlayerData.player) \
			and PlayerData.player.has_method("update_grab_radius"):
		PlayerData.player.call("update_grab_radius")
