extends SceneTree

const Projection := preload("res://Visual/Oblique/fixed_oblique_projection_2d.gd")

func _init() -> void:
	var failed := false
	Projection.configure(true, -6.0, 0.82, 1.0)
	var vectors := [Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2(3.5, -8.25)]
	for world_vector: Vector2 in vectors:
		var screen_vector: Vector2 = Projection.world_vector_to_screen(world_vector)
		var round_trip: Vector2 = Projection.screen_vector_to_world(screen_vector)
		if not round_trip.is_equal_approx(world_vector):
			push_error("Projection round trip failed: %s -> %s" % [world_vector, round_trip])
			failed = true
	Projection.configure(false, -6.0, 0.82, 1.0)
	if Projection.world_vector_to_screen(Vector2(2.0, 3.0)) != Vector2(2.0, 3.0):
		push_error("Disabled projection changed a vector.")
		failed = true
	Projection.configure(true, -6.0, 0.0, 1.0)
	var guarded := Projection.screen_vector_to_world(Vector2.ONE)
	if not is_finite(guarded.x) or not is_finite(guarded.y):
		push_error("Invalid vertical scale guard produced a non-finite vector.")
		failed = true
	if failed:
		print("FAIL: fixed oblique projection")
		quit(1)
	else:
		print("PASS: fixed oblique projection")
		quit(0)
