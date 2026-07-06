extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var orbit_script := load("res://Player/Weapons/Instances/orbit.gd") as Script
	if orbit_script == null:
		return _fail("missing Orbit script")
	var orbit: Node = orbit_script.new()

	var stale_satellite := Node2D.new()
	orbit.set("satellites", [stale_satellite])
	stale_satellite.free()

	var visible_satellites: Array = orbit.call("get_satellites")
	if visible_satellites.size() != 0:
		return _fail("freed satellite should not be returned")

	orbit.call("_prune_satellites")
	var cached_satellites: Array = orbit.get("satellites")
	if cached_satellites.size() != 0:
		return _fail("freed satellite should be pruned")

	orbit.free()
	printerr("PASS: Orbit freed satellite cache guard")
	quit(0)

func _fail(message: String) -> void:
	push_error("FAIL: Orbit freed satellite cache guard: %s" % message)
	quit(1)
