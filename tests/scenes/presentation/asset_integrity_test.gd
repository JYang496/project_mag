extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PRESENTATION_POLICY := preload("res://Visual/pixel_art_policy.gd")
const CELL_PRESENTATION_CONTROLLER := preload("res://Board/Cells/cell_presentation_controller.gd")

class DummyActivationVisual:
	extends Node2D
	var configured := false

	func configure(
		_board_enabled: bool,
		_player_inside: bool,
		_has_task: bool,
		_cell_rect: Rect2
	) -> void:
		configured = true

var _failed := false


func _ready() -> void:
	_validate_policy_targets()
	_validate_cell_presentation_contract()
	_validate_module_assets()
	print("FAIL: presentation asset integrity" if _failed else "PASS: presentation asset integrity")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _validate_policy_targets() -> void:
	var targets := [
		Vector2(PRESENTATION_POLICY.PLAYER_FRAME_SIZE),
		Vector2(PRESENTATION_POLICY.PLAYER_SUPPORT_FRAME_SIZE),
		PRESENTATION_POLICY.PROJECTILE_STANDARD_SIZE,
		PRESENTATION_POLICY.PROJECTILE_CANNON_SIZE,
		PRESENTATION_POLICY.PROJECTILE_LARGE_SIZE,
		Vector2(PRESENTATION_POLICY.ENEMY_STANDARD_FRAME_SIZE),
		Vector2(PRESENTATION_POLICY.ENEMY_ELITE_FRAME_SIZE),
		Vector2(PRESENTATION_POLICY.BOARD_CELL_FRAME_SIZE),
	]
	for target in targets:
		_expect(
			PRESENTATION_POLICY.is_integer_target_size(target),
			"presentation target must contain positive whole logical pixels: %s" % target
		)


func _validate_cell_presentation_contract() -> void:
	var controller = CELL_PRESENTATION_CONTROLLER.new()
	var texture_root := Node2D.new()
	var activation := DummyActivationVisual.new()
	var task_marker := Node2D.new()
	controller.set_visuals_visible(false, texture_root, activation, task_marker, true)
	_expect(
		not texture_root.visible and not activation.visible and not task_marker.visible,
		"cell presentation must hide every visual layer together"
	)
	controller.configure_activation(
		activation,
		true,
		true,
		true,
		Rect2(Vector2.ZERO, Vector2(64.0, 64.0))
	)
	_expect(activation.configured, "cell presentation must forward activation state")
	texture_root.free()
	activation.free()
	task_marker.free()


func _validate_module_assets() -> void:
	var module_dir := DirAccess.open("res://Player/Weapons/Modules")
	_expect(module_dir != null, "weapon module scene directory must open")
	if module_dir == null:
		return
	var scene_filenames := module_dir.get_files()
	scene_filenames.sort()
	for filename in scene_filenames:
		if not filename.begins_with("wmod_") or filename.get_extension() != "tscn" or filename == "wmod_base.tscn":
			continue
		var scene_path := "res://Player/Weapons/Modules/%s" % filename
		var module_scene := load(scene_path) as PackedScene
		var module := module_scene.instantiate() if module_scene != null else null
		_expect(module != null, "module scene must instantiate: %s" % scene_path)
		if module == null:
			continue
		var sprite := module.get_node_or_null("Sprite") as Sprite2D
		_expect(
			sprite != null and sprite.texture != null,
			"module must expose a loadable icon texture: %s" % scene_path
		)
		module.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
