extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const PLAYER_SPAWNER_SCRIPT := preload("res://World/player_spawner.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail(1, "StartupFeatureTestLoadout: failed to instantiate player.")
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame
	PLAYER_SPAWNER_SCRIPT.grant_startup_feature_test_loadout(player)

	if PlayerData.player_weapon_list.size() != PLAYER_SPAWNER_SCRIPT.STARTUP_FEATURE_TEST_WEAPON_COUNT:
		_fail(
			2,
			"StartupFeatureTestLoadout: expected %d weapons, got %d." %
				[
					PLAYER_SPAWNER_SCRIPT.STARTUP_FEATURE_TEST_WEAPON_COUNT,
					PlayerData.player_weapon_list.size(),
				]
		)
		return
	if InventoryData.temporary_modules.size() != PLAYER_SPAWNER_SCRIPT.STARTUP_FEATURE_TEST_MODULE_PATHS.size():
		_fail(
			3,
			"StartupFeatureTestLoadout: expected %d modules, got %d." %
				[
					PLAYER_SPAWNER_SCRIPT.STARTUP_FEATURE_TEST_MODULE_PATHS.size(),
					InventoryData.temporary_modules.size(),
				]
		)
		return

	var actual_module_paths: PackedStringArray = []
	for module_instance in InventoryData.temporary_modules:
		actual_module_paths.append(str(module_instance.scene_file_path))
	actual_module_paths.sort()
	var expected_module_paths := PLAYER_SPAWNER_SCRIPT.STARTUP_FEATURE_TEST_MODULE_PATHS.duplicate()
	expected_module_paths.sort()
	if actual_module_paths != expected_module_paths:
		_fail(
			4,
			"StartupFeatureTestLoadout: expected modules %s, got %s." %
				[expected_module_paths, actual_module_paths]
		)
		return

	InventoryData.reset_runtime_state()
	print("StartupFeatureTestLoadout: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
