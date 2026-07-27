extends Control

const PLAYER_STATUS_HUD := preload("res://UI/scripts/components/player_status_hud.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.18, 0.21, 0.23)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var states := [
		{"energy": 25.0, "remaining": 0.0, "name": "Charging"},
		{"energy": 75.0, "remaining": 3.7, "name": "Cooldown"},
		{"energy": 75.0, "remaining": 0.0, "name": "Ready"},
	]
	for index in range(states.size()):
		var state: Dictionary = states[index]
		var caption := Label.new()
		caption.position = Vector2(20.0, 30.0 + float(index) * 90.0)
		caption.size = Vector2(80.0, 24.0)
		caption.text = str(state.name)
		add_child(caption)
		var hud := PLAYER_STATUS_HUD.new()
		hud.position = Vector2(100.0, 10.0 + float(index) * 90.0)
		add_child(hud)
		hud.set_health(9, 9, 3, 9)
		hud.set_energy(float(state.energy), 125.0)
		hud.set_skill_cost(50.0)
		hud.set_cooldown(float(state.remaining), 8.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var output_path := OS.get_environment("PLAYER_STATUS_HUD_QA_PATH")
	if output_path.is_empty():
		output_path = "user://player_status_hud_visual_probe.png"
	var error := image.save_png(output_path)
	print("HUD_PROBE_PATH=%s" % ProjectSettings.globalize_path(output_path))
	print("PASS" if error == OK else "FAIL save error=%d" % error)
	await TEST_TEARDOWN.finish(self, 0 if error == OK else 1)
