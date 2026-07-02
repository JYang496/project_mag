extends Node

const START_SCENE_PATH := "res://World/Start.tscn"
const WORLD_SCENE_PATH := "res://World/world.tscn"
const TIMEOUT_MSEC := 20000

var _started_usec := 0

func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	call_deferred("_run")

func _run() -> void:
	_stage("probe_ready")
	var start_scene := load(START_SCENE_PATH) as PackedScene
	if start_scene == null:
		_fail("failed to load start scene")
		return
	_stage("start_scene_loaded")
	var start_instance := start_scene.instantiate()
	if start_instance == null:
		_fail("failed to instantiate start scene")
		return
	get_tree().current_scene = null
	get_tree().root.add_child(start_instance)
	get_tree().current_scene = start_instance
	_stage("start_scene_instantiated")
	var start_button := start_instance.get_node_or_null(
		"CanvasLayer/GUI/Background/HBoxMargin/HBoxContainer/MenuContainer/VBoxContainer/Start"
	) as Button
	if start_button == null:
		_fail("failed to find start button")
		return
	start_button.emit_signal("pressed")
	_stage("world_request_started")
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == WORLD_SCENE_PATH:
			_stage("world_scene_entered")
			if SpawnData.level_list.is_empty():
				_fail("SpawnData was not prepared before entering world")
				return
			var player_deadline := Time.get_ticks_msec() + 5000
			while (PlayerData.player == null or PlayerData.player_weapon_list.is_empty()) and Time.get_ticks_msec() < player_deadline:
				await get_tree().process_frame
			if PlayerData.player == null or PlayerData.player_weapon_list.is_empty():
				_fail("player runtime was not ready after world entry")
				return
			_stage("player_runtime_ready")
			print("StartupBaselineProbe: PASS")
			get_tree().quit(0)
			return
	_fail("timed out waiting for world entry")

func _stage(stage_name: String) -> void:
	var elapsed_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	print("StartupBaselineStage: %s elapsed_ms=%.3f" % [stage_name, elapsed_ms])

func _fail(message: String) -> void:
	push_error("StartupBaselineProbe: %s" % message)
	print("StartupBaselineProbe: FAIL")
	get_tree().quit(1)
