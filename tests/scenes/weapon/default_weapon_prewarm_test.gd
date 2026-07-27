extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")


func _ready() -> void:
	var failed := false
	var mecha := DataHandler.read_mecha_data("1")
	if mecha == null or mecha.default_weapon_id.is_empty():
		push_error("default weapon prewarm test requires mecha 1 with a default weapon")
		failed = true
	else:
		var weapon := DataHandler.read_weapon_data(mecha.default_weapon_id) as WeaponDefinition
		if weapon == null or weapon.scene_path.is_empty():
			push_error("default weapon prewarm test could not resolve the weapon definition")
			failed = true
		else:
			weapon.set("_scene_cache", null)
			weapon.set("_scene_request_started", false)
			if not DataHandler.prewarm_mecha_default_weapon("1"):
				push_error("default weapon prewarm must load the configured scene")
				failed = true
			var first_scene := weapon.get_scene()
			if first_scene == null:
				push_error("default weapon prewarm must cache a PackedScene")
				failed = true
			elif weapon.get_scene() != first_scene:
				push_error("default weapon prewarm must reuse the cached PackedScene")
				failed = true
			if bool(weapon.get("_scene_request_started")):
				push_error("default weapon prewarm must not leave a threaded request active")
				failed = true
			var load_status := ResourceLoader.load_threaded_get_status(weapon.scene_path)
			if load_status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("default weapon prewarm must not create a threaded ResourceLoader request")
				failed = true
	if failed:
		print("FAIL default weapon synchronous prewarm")
	else:
		print("PASS default weapon synchronous prewarm")
	await TEST_TEARDOWN.finish(self, 1 if failed else 0)
