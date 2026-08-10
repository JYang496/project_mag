extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const START_SCENE := preload("res://World/Start.tscn")
const BACKDROP_SCRIPT := preload("res://UI/scripts/components/start_menu_backdrop.gd")

var _failed := false
var _menu: Node


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_menu = START_SCENE.instantiate()
	add_child(_menu)
	await get_tree().create_timer(0.48).timeout
	_test_landing_geometry()
	_test_landing_hierarchy()
	_test_backdrop_semantics()
	await _test_preview_handoff_lifecycle()
	await _test_settings_geometry()
	print("FAIL start menu layout" if _failed else "PASS start menu layout")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)
	_menu = null


func _test_landing_geometry() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	var main_column := _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn") as Control
	var safe_area := _menu.get_node("CanvasLayer/GUI/SafeArea") as Control
	var nav := _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation") as Control
	var input_hint := _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/InputHint") as Control
	_expect(main_column.global_position.x >= 70.0, "main menu must preserve the 72px left safe margin (main=%s safe_pos=%s safe_size=%s margin=%s)" % [main_column.global_position, safe_area.global_position, safe_area.size, safe_area.get_theme_constant("margin_left")])
	_expect(main_column.global_position.y >= 46.0, "main menu must preserve the 48px top safe margin")
	_expect(main_column.size.x >= 390.0, "main menu action column must remain at least 390px wide")
	_expect(viewport_rect.encloses(Rect2(nav.global_position, nav.size)), "navigation must remain inside the viewport")
	_expect(input_hint.global_position.y + input_hint.size.y <= 680.0, "input hint must remain above the bottom safe margin")
	var focus_owner := get_viewport().gui_get_focus_owner()
	var expected_focus := _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Continue") if not (_menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Continue") as Button).disabled else _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation/NewGame")
	_expect(focus_owner == expected_focus, "initial keyboard focus must select the first available game action")


func _test_landing_hierarchy() -> void:
	var navigation := _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation")
	var settings_panel := _menu.get_node("CanvasLayer/GUI/SettingsPanel") as Control
	_expect(navigation.get_node_or_null("NewGame") is Button, "landing page must expose New Game as a direct action")
	_expect(navigation.get_node_or_null("Settings") is Button, "landing page must expose Settings as navigation")
	_expect(navigation.get_node_or_null("ResolutionOption") == null, "landing page must not mix resolution controls into primary navigation")
	_expect(not settings_panel.visible, "settings panel must be hidden on initial entry")
	_expect(_menu.find_children("*", "SubViewport", true, false).is_empty(), "lightweight menu preview must not render a second live viewport")
	_expect(_menu.find_children("*", "CharacterBody2D", true, false).is_empty(), "lightweight menu preview must not instantiate the live player")
	_expect(_menu.find_children("*", "Area2D", true, false).is_empty(), "lightweight menu preview must not create rest-area physics")
	_expect(get_tree().get_nodes_in_group(&"rest_area").is_empty(), "menu prewarm must cache resources without instantiating the World rest area")


func _test_backdrop_semantics() -> void:
	var viewport_size := Vector2(1280.0, 720.0)
	var menu_layout: Dictionary = BACKDROP_SCRIPT.preview_layout(viewport_size, 0.0)
	var midpoint_layout: Dictionary = BACKDROP_SCRIPT.preview_layout(viewport_size, 0.5)
	var full_layout: Dictionary = BACKDROP_SCRIPT.preview_layout(viewport_size, 1.0)
	var stage_rect: Rect2 = menu_layout.stage_rect
	var menu_platform: Rect2 = menu_layout.platform_rect
	var full_platform: Rect2 = full_layout.platform_rect
	var menu_cells: Array = menu_layout.cells
	_expect(
		stage_rect.position.x >= 540.0,
		"rest-area preview must preserve clear separation from the left menu"
	)
	_expect(
		stage_rect.end.x <= viewport_size.x - 24.0 and stage_rect.position.y >= 24.0,
		"rest-area preview must remain inside the right-side visual safe area"
	)
	_expect(
		stage_rect.encloses(menu_platform),
		"standby platform must remain contained by the menu preview stage"
	)
	_expect(
		menu_platform.size.x >= stage_rect.size.x * 0.95
			and menu_platform.size.y >= stage_rect.size.y * 0.95,
		"standby platform must use the enlarged right-side preview footprint"
	)
	_expect(
		Geometry2D.is_point_in_polygon(Vector2(menu_layout.player_center), PackedVector2Array(menu_cells[4].quad)),
		"standby player must stay anchored inside the projected center cell"
	)
	_expect(
		menu_cells.size() == 9,
		"loading area must retain the live rest area's 3x3 spatial structure"
	)
	_expect(
		float(menu_layout.top_width) < float(menu_layout.bottom_width),
		"loading area must use a top-narrow, bottom-wide 2.5D projection"
	)
	_expect(
		not menu_layout.has("upgrade_center") and not menu_layout.has("warehouse_center"),
		"menu preview must not reserve semantic positions for live-world facilities"
	)
	_expect(
		Rect2(midpoint_layout.stage_rect).position.x < stage_rect.position.x
			and Rect2(midpoint_layout.stage_rect).size.x > stage_rect.size.x,
		"handoff midpoint must visibly expand the preview toward the full viewport"
	)
	_expect(
		full_platform.size.x >= viewport_size.x * 0.90
			and full_platform.position.x <= 64.0
			and full_platform.end.x >= viewport_size.x - 64.0,
		"completed handoff must make the rest platform the primary full-screen image"
	)
	var pulse_peak: Dictionary = BACKDROP_SCRIPT.animation_state_at(1.5)
	_expect(
		float(pulse_peak.pulse) > 0.99,
		"standby center ring must have a deterministic readable pulse peak"
	)
	var loop_a: Dictionary = BACKDROP_SCRIPT.animation_state_at(0.5)
	var loop_b: Dictionary = BACKDROP_SCRIPT.animation_state_at(6.5)
	_expect(
		is_equal_approx(float(loop_a.progress), float(loop_b.progress))
			and is_equal_approx(float(loop_a.pulse), float(loop_b.pulse)),
		"rest-area standby animation must loop without semantic state drift"
	)
	for supported_size in [Vector2(1600.0, 900.0), Vector2(1920.0, 1080.0), Vector2(2560.0, 1440.0)]:
		var supported_menu: Dictionary = BACKDROP_SCRIPT.preview_layout(supported_size, 0.0)
		var supported_full: Dictionary = BACKDROP_SCRIPT.preview_layout(supported_size, 1.0)
		_expect(
			Rect2(supported_menu.stage_rect).position.x >= supported_size.x * 0.42,
			"standby preview must preserve the left action column at %s" % supported_size
		)
		_expect(
			Rect2(Vector2.ZERO, supported_size).encloses(Rect2(supported_full.stage_rect)),
			"expanded preview must remain inside the supported viewport at %s" % supported_size
		)
		_expect(
			Geometry2D.is_point_in_polygon(
				Vector2(supported_full.player_center),
				PackedVector2Array((supported_full.cells as Array)[4].quad)
			),
			"player anchor must remain in the projected center cell through handoff at %s" % supported_size
		)


func _test_preview_handoff_lifecycle() -> void:
	LoadingPerformance.begin_world_preview_handoff()
	await get_tree().create_timer(0.12).timeout
	var loading_overlay := LoadingPerformance.get("_world_build_overlay") as CanvasLayer
	var loading_root := LoadingPerformance.get("_world_build_overlay_root") as ColorRect
	var preview := LoadingPerformance.get("_world_preview") as Control
	_expect(LoadingPerformance.is_world_preview_handoff_active(), "world-entry preview must expose an active handoff state")
	_expect(loading_overlay != null and loading_overlay.visible, "world-entry preview must persist above the menu during handoff")
	_expect(loading_root != null and loading_root.mouse_filter == Control.MOUSE_FILTER_STOP, "handoff overlay must block duplicate menu input")
	_expect(preview != null and preview.visible, "handoff must render the same lightweight rest preview in its persistent overlay")
	_expect(float(preview.get("handoff_progress")) > 0.0, "handoff preview must begin expanding immediately")
	_expect(bool(preview.get("loading_active")), "clicking a game action must switch the preview from calibration to real loading")
	var initial_loading_progress := float(preview.get("loading_progress"))
	_expect(initial_loading_progress > 0.0, "real loading handoff must publish its initial run-state phase")
	await LoadingPerformance.wait_for_world_preview_safe_scene_change()
	_expect(
		float(preview.get("handoff_progress")) > 0.35
			and float(preview.get("handoff_progress")) < 0.95,
		"safe scene switching must begin staged world construction while the preview expansion is still animating"
	)
	LoadingPerformance.update_world_preview_loading_progress(0.42)
	LoadingPerformance.update_world_preview_loading_progress(0.20)
	_expect(
		is_equal_approx(float(preview.get("loading_progress")), 0.42),
		"loading materialization must advance monotonically and ignore stale progress"
	)
	LoadingPerformance.cancel_world_preview_handoff()
	await get_tree().process_frame
	_expect(not LoadingPerformance.is_world_preview_handoff_active(), "cancelled handoff must clear its lifecycle state")
	_expect(not loading_overlay.visible and not preview.visible, "cancelled handoff must release all persistent visual coverage")


func _test_settings_geometry() -> void:
	_menu.call("_open_settings")
	await get_tree().create_timer(0.24).timeout
	var panel := _menu.get_node("CanvasLayer/GUI/SettingsPanel") as Control
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	_expect(panel.visible, "settings navigation must reveal the settings panel")
	_expect(viewport_rect.encloses(Rect2(panel.global_position, panel.size)), "settings panel must remain fully inside 1280x720")
	_expect(panel.size.x >= 550.0 and panel.size.y >= 640.0, "settings panel must preserve its designed information footprint")
	_expect(panel.get_node_or_null("Margin/Content/AudioSlot/AudioSettingsControls") != null, "settings panel must own audio controls")
	_expect(panel.get_node_or_null("Margin/Content/AutoAim") is CheckButton, "settings panel must own assist controls")
	var footer := panel.get_node("Margin/Content/SettingsFooter") as Control
	_expect(footer.global_position.y + footer.size.y <= panel.global_position.y + panel.size.y - 24.0, "settings content must preserve its bottom inset")
	var cancel_event := InputEventMouseButton.new()
	cancel_event.button_index = MOUSE_BUTTON_RIGHT
	cancel_event.pressed = true
	_menu.call("_unhandled_input", cancel_event)
	await get_tree().create_timer(0.18).timeout
	_expect(not panel.visible, "right-click cancel must close settings and restore the landing page")
	_expect(get_viewport().gui_get_focus_owner() == _menu.get_node("CanvasLayer/GUI/SafeArea/MainColumn/Navigation/Settings"), "closing settings must restore keyboard focus to Settings")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
