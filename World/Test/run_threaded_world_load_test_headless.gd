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
			print("PASS: threaded world load entered world with spawn data ready")
			get_tree().quit(0)
			return
	_fail("Timed out waiting for threaded world load.")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
