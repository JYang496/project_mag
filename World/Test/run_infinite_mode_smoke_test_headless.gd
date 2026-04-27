extends SceneTree

var _completed := false

func _initialize() -> void:
	var packed := load("res://World/Test/infinite_mode_smoke_test.tscn") as PackedScene
	if packed == null:
		push_error("FAIL: unable to load infinite_mode_smoke_test.tscn")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	if not scene.has_signal("test_finished"):
		push_error("FAIL: infinite_mode_smoke_test is missing test_finished signal")
		quit(1)
		return
	scene.connect("test_finished", Callable(self, "_on_test_finished"))
	call_deferred("_timeout_guard")

func _on_test_finished(success: bool) -> void:
	_completed = true
	if success:
		print("PASS: infinite mode smoke test")
		quit(0)
		return
	push_error("FAIL: infinite mode smoke test")
	quit(1)

func _timeout_guard() -> void:
	await create_timer(12.0).timeout
	if _completed:
		return
	push_error("FAIL: infinite mode smoke test timeout")
	quit(1)
