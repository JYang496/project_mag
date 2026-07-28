# Archived 2026-07-28: release-specific screenshot acceptance probe.
extends Control

const PLAYER_STATUS_HUD := preload("res://UI/scripts/components/player_status_hud.gd")
const COMBAT_RESOURCE_METER := preload("res://UI/scripts/components/combat_resource_meter.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const MAIN_SLOT := preload("res://UI/themes/modern/weapon_slot_main.png")
const OFFHAND_SLOT := preload("res://UI/themes/modern/weapon_slot_offhand.png")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.008, 0.018, 0.026, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var status_hud := PLAYER_STATUS_HUD.new() as Control
	status_hud.position = Vector2(270.0, 380.0)
	add_child(status_hud)
	status_hud.set_health(72, 100, 38, 60)
	status_hud.set_energy(86.0, 125.0)
	status_hud.set_skill_cost(50.0)

	var heat_meter := COMBAT_RESOURCE_METER.new() as Control
	heat_meter.position = Vector2(404.0, 112.0)
	add_child(heat_meter)
	heat_meter.set_resource(&"heat", 0.68, &"warning", "68%")

	var slot_origin := Vector2(274.0, 32.0)
	for index in range(4):
		var slot := TextureRect.new()
		slot.texture = MAIN_SLOT if index == 0 else OFFHAND_SLOT
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.position = slot_origin + Vector2(104.0 if index > 0 else 0.0, 0.0) + Vector2(maxi(index - 1, 0) * 80.0, 0.0)
		slot.size = Vector2(96.0, 72.0) if index == 0 else Vector2(72.0, 72.0)
		add_child(slot)

	await get_tree().process_frame
	await get_tree().process_frame
	var output_path := OS.get_environment("MODERN_HUD_QA_PATH")
	if output_path.is_empty():
		output_path = "user://modern_combat_hud_visual_probe.png"
	var error := get_viewport().get_texture().get_image().save_png(output_path)
	print("MODERN_HUD_PROBE_PATH=%s" % ProjectSettings.globalize_path(output_path))
	print("PASS" if error == OK else "FAIL save error=%d" % error)
	await TEST_TEARDOWN.finish(self, 0 if error == OK else 1)
