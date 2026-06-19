extends Node

const START_SCENE_PATH := "res://World/Start.tscn"
const WORLD_SCENE_PATH := "res://World/world.tscn"
const TIMEOUT_MSEC := 15000

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var start_scene := load(START_SCENE_PATH) as PackedScene
	if start_scene == null:
		_fail("Failed to load start scene.")
		return
	get_tree().current_scene = null
	var start_instance := start_scene.instantiate()
	get_tree().root.add_child(start_instance)
	get_tree().current_scene = start_instance
	var start_button := start_instance.get_node_or_null(
		"CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/Start"
	) as Button
	if start_button == null:
		_fail("Failed to find start button.")
		return
	start_button.emit_signal("pressed")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == WORLD_SCENE_PATH:
			if SpawnData.level_list.is_empty():
				_fail("SpawnData was not prepared before entering world.")
				return
			if not GlobalVariables.weapon_branch_list.is_empty():
				_fail("Weapon branch data was loaded during title-to-world startup.")
				return
			var ui := current.get_node_or_null("UI") as UI
			if ui != null and ui.module_shop_list_view != null:
				_fail("Module shop UI was created during title-to-world startup.")
				return
			var player_deadline := Time.get_ticks_msec() + 3000
			while (PlayerData.player == null or PlayerData.player_weapon_list.is_empty()) and Time.get_ticks_msec() < player_deadline:
				await get_tree().process_frame
			if PlayerData.player_weapon_list.size() != 1:
				_fail("Startup feature test loadout ran during normal world startup.")
				return
			if not InventoryData.temporary_modules.is_empty():
				_fail("Temporary test modules were loaded during normal world startup.")
				return
			print("PASS: threaded world load entered world with spawn data ready")
			get_tree().quit(0)
			return
	_fail("Timed out waiting for threaded world load.")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
