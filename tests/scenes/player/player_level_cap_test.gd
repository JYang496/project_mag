extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HEAVY_ASSAULT := preload("res://data/mechas/HeavyAssault.tres")
const PLAYER_SPAWNER_SCRIPT := preload("res://World/player_spawner.gd")

var _failed := false
var _original_mech_data: MechaDefinition
var _original_autosave_data: Dictionary


func _ready() -> void:
	_original_mech_data = GlobalVariables.mech_data
	_original_autosave_data = GlobalVariables.autosave_data.duplicate(true)
	GlobalVariables.mech_data = HEAVY_ASSAULT

	_test_exp_uses_the_threshold_from_the_level_being_completed()
	_test_level_ten_discards_additional_exp()
	_test_direct_level_assignment_is_capped()
	_test_legacy_high_level_save_is_clamped_before_stat_lookup()

	print("FAIL player level cap" if _failed else "PASS player level cap")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)


func _test_exp_uses_the_threshold_from_the_level_being_completed() -> void:
	PlayerData.reset_runtime_state()
	PlayerData.player_level = 1
	PlayerData.player_exp = 15
	_expect(PlayerData.player_level == 2, "10 EXP at level 1 must advance exactly one level.")
	_expect(PlayerData.player_exp == 5, "EXP above the completed level threshold must carry forward.")


func _test_level_ten_discards_additional_exp() -> void:
	PlayerData.reset_runtime_state()
	PlayerData.player_level = 9
	PlayerData.player_exp = 95
	_expect(PlayerData.player_level == PlayerData.MAX_PLAYER_LEVEL, "Level progression must stop at the Playtest cap.")
	_expect(PlayerData.player_exp == 0, "Reaching the Playtest cap must discard surplus EXP.")

	PlayerData.player_exp = 99999
	_expect(PlayerData.player_level == PlayerData.MAX_PLAYER_LEVEL, "Additional EXP must not advance a max-level player.")
	_expect(PlayerData.player_exp == 0, "A max-level player must not accumulate unusable EXP.")


func _test_direct_level_assignment_is_capped() -> void:
	PlayerData.reset_runtime_state()
	PlayerData.player_level = 42
	_expect(PlayerData.player_level == PlayerData.MAX_PLAYER_LEVEL, "Direct level assignment must respect the Playtest cap.")
	_expect(PlayerData.player_exp == 0, "Directly restoring max level must clear stale EXP.")


func _test_legacy_high_level_save_is_clamped_before_stat_lookup() -> void:
	PlayerData.reset_runtime_state()
	GlobalVariables.mech_data = HEAVY_ASSAULT
	GlobalVariables.autosave_data = {
		"current_level": "42",
		"current_exp": "999",
	}
	var spawner := PLAYER_SPAWNER_SCRIPT.new()
	spawner.set_start_up_status()
	_expect(PlayerData.player_level == PlayerData.MAX_PLAYER_LEVEL, "Legacy saves above level 10 must restore at the cap.")
	_expect(PlayerData.player_exp == 0, "Legacy max-level saves must not retain unusable EXP.")
	spawner.free()


func _reset_runtime_state() -> void:
	PlayerData.reset_runtime_state()
	GlobalVariables.mech_data = _original_mech_data
	GlobalVariables.autosave_data = _original_autosave_data


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
