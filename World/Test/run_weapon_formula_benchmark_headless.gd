extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://World/Test/weapon_formula_benchmark.tscn")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var cfg: Resource = scene.get("config")
	if cfg != null:
		cfg.set("auto_start_on_ready", false)
		cfg.set("quit_on_completion", true)
		cfg.set("auto_discover_standalone_weapons", false)
		cfg.set("weapon_ids", PackedStringArray(["1", "5", "4", "8", "9", "2", "13", "21", "25", "26", "17", "10", "3", "7", "11"]))
		cfg.set("test_duration_sec", 3.0)
		cfg.set("warmup_sec", 0.2)
		cfg.set("simulation_time_scale", 6.0)
	scene.call_deferred("_on_start_pressed")
