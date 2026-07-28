extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const LAYOUT := preload("res://UI/scripts/management/ui_layout_policy.gd")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PROJECTED_WORLD_UI := preload("res://Visual/Oblique/projected_world_ui_service.gd")

const VIEWPORTS := [
	Vector2(1280.0, 720.0),
	Vector2(1600.0, 900.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
]

var _failed := false

func _ready() -> void:
	for viewport_size in VIEWPORTS:
		_test_management_layout(viewport_size)
		_test_expandable_primary_menus(viewport_size)
		_test_hud_lanes(viewport_size)
	_test_pause_modal_layer_priority()
	print("FAIL UI layout policy" if _failed else "PASS UI layout policy")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_management_layout(viewport_size: Vector2) -> void:
	var safe := LAYOUT.safe_margin(viewport_size)
	var usable := Rect2(safe, viewport_size - safe * 2.0)
	var panel := LAYOUT.management_panel_rect(viewport_size)
	_expect(usable.encloses(panel), "%s management panel exceeds safe area" % viewport_size)
	_expect(panel.size.x > 0.0 and panel.size.y > 0.0, "%s management panel collapsed" % viewport_size)

func _test_expandable_primary_menus(viewport_size: Vector2) -> void:
	var previous_height := 0.0
	for entry_count in [1, 2, 4, 6]:
		var panel := LAYOUT.primary_menu_rect(viewport_size, entry_count)
		_expect(
			Rect2(Vector2.ZERO, viewport_size).encloses(panel),
			"%s primary menu with %d entries exceeds viewport" % [viewport_size, entry_count]
		)
		_expect(
			panel.size.y >= previous_height,
			"%s primary menu must not shrink when entries increase" % viewport_size
		)
		previous_height = panel.size.y

func _test_hud_lanes(viewport_size: Vector2) -> void:
	var left := LAYOUT.hud_left_lane(viewport_size)
	var right := LAYOUT.hud_right_lane(viewport_size)
	var center := LAYOUT.hud_center_safe_rect(viewport_size)
	_expect(not left.intersects(right), "%s left and right HUD lanes overlap" % viewport_size)
	_expect(not left.intersects(center), "%s left HUD lane enters combat-safe center" % viewport_size)
	_expect(not right.intersects(center), "%s right HUD lane enters combat-safe center" % viewport_size)
	_expect(center.size.x > 0.0 and center.size.y > 0.0, "%s combat-safe center collapsed" % viewport_size)

func _test_pause_modal_layer_priority() -> void:
	var ui := UI_SCENE.instantiate() as CanvasLayer
	var pause_layer := ui.get_node_or_null("PauseMenuLayer") as CanvasLayer
	var pause_root := ui.get_node_or_null("PauseMenuLayer/PauseMenuRoot") as Control
	_expect(pause_layer != null, "pause menu must own a dedicated CanvasLayer")
	_expect(pause_root != null and pause_root.get_parent() == pause_layer, "pause blocker must live inside the dedicated modal layer")
	if pause_layer != null:
		_expect(pause_layer.layer == UI.PAUSE_MODAL_CANVAS_LAYER, "pause layer must use the reserved modal priority")
		_expect(pause_layer.layer > PROJECTED_WORLD_UI.LAYER_ORDER, "pause layer must render above projected damage labels")
	ui.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
