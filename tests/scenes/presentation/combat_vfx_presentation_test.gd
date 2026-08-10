extends Node2D

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const CAPTURE := preload("res://tests/infrastructure/presentation_capture.gd")
const MUZZLES := [
	preload("res://Player/Weapons/Feedback/muzzle_flash_light.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_heavy.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_energy.tscn"),
	preload("res://Player/Weapons/Feedback/muzzle_flash_plasma.tscn"),
]
const HIT_SERVICE := preload("res://Combat/Vfx/combat_hit_vfx_service.gd")
const HIT_PROFILE := preload("res://Combat/Vfx/combat_hit_vfx_profile.gd")

var _failed := false


func _ready() -> void:
	_build_backdrop("COMBAT FEEDBACK · MUZZLE SIGNATURES / HIT RESPONSES")
	for index in range(MUZZLES.size()):
		var flash := MUZZLES[index].instantiate() as Node2D
		flash.position = Vector2(220.0, 190.0 + index * 125.0)
		flash.scale = Vector2.ONE * 2.5
		add_child(flash)
		flash.call("setup", Vector2.RIGHT)
		flash.process_mode = Node.PROCESS_MODE_DISABLED
		_add_caption(Vector2(345.0, 174.0 + index * 125.0), ["LIGHT", "HEAVY", "ENERGY", "PLASMA"][index])
	var service := HIT_SERVICE.new()
	add_child(service)
	for index in range(6):
		var column := index % 3
		var row := index / 3
		service.play(Vector2(730.0 + column * 190.0, 265.0 + row * 220.0), HIT_PROFILE.create(index))
		_add_caption(Vector2(680.0 + column * 190.0, 315.0 + row * 220.0), "HIT %02d" % (index + 1))
	_expect(await CAPTURE.capture(self, "presentation.combat_vfx"), "combat VFX presentation must satisfy the 1280x720 capture contract")
	print("FAIL: presentation combat vfx" if _failed else "PASS: presentation combat vfx")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: %s" % message)


func _build_backdrop(title: String) -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280.0, 720.0)
	background.color = Color("10151d")
	background.z_index = -10
	add_child(background)
	var divider := ColorRect.new()
	divider.position = Vector2(535.0, 120.0)
	divider.size = Vector2(2.0, 510.0)
	divider.color = Color(0.25, 0.56, 0.68, 0.34)
	divider.z_index = -5
	add_child(divider)
	_add_caption(Vector2(64.0, 42.0), title, 24)
	_add_caption(Vector2(150.0, 112.0), "WEAPON CLASS", 16)
	_add_caption(Vector2(810.0, 112.0), "IMPACT CLASS", 16)


func _add_caption(at: Vector2, text: String, font_size: int = 14) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("b9d5df"))
	add_child(label)
