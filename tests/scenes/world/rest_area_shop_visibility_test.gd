extends Node

const RestAreaType := preload("res://World/rest_area.gd")
const RestAreaScene := preload("res://World/rest_area.tscn")
const ZoneVisualsType := preload("res://World/rest_area_zone_visuals.gd")
const HintPresenterType := preload("res://World/rest_area_hint_presenter.gd")
const EXPECTED_REST_GROUND_PATH := "res://asset/images/cells/rest_area_safe_medical.png"

class VisualOwner:
	extends Node2D
	var shop_available := false

	func _is_zone_available(zone_id: int) -> bool:
		return zone_id != 0 or shop_available

	func _get_zone_rect_local(zone_id: int) -> Rect2:
		return Rect2(Vector2(zone_id % 3, zone_id / 3) * 100.0, Vector2(100.0, 100.0))

class HintOwner:
	extends Node2D
	var show_intro := true
	var hover_zone_id := -1
	var selected_zone_id := 4
	var is_auto_moving := false

	func _should_show_zone_hint_label(zone_id: int, _is_center_action_hint: bool = false) -> bool:
		return show_intro or zone_id == 1

	func _get_zone_rect_local(zone_id: int) -> Rect2:
		return Rect2(Vector2(zone_id % 3, zone_id / 3) * 160.0, Vector2(160.0, 160.0))

func _ready() -> void:
	var failed := false
	var previous_completed_levels := PlayerData.run_completed_levels
	var scene_rest_area := RestAreaScene.instantiate() as RestArea
	add_child(scene_rest_area)
	var ground_sprite := scene_rest_area.get_node_or_null("Texture/Sprite2D") as Sprite2D
	failed = _check(
		ground_sprite != null
			and ground_sprite.texture != null
			and ground_sprite.texture.resource_path == EXPECTED_REST_GROUND_PATH,
		"rest area runtime initialization must preserve its dedicated ground texture"
	) or failed
	var warehouse_prop := Sprite2D.new()
	warehouse_prop.name = "HybridProp2"
	scene_rest_area.get_node("ZoneVisuals").add_child(warehouse_prop)
	warehouse_prop.global_position = Vector2(418.0, 96.0)
	var projected_hint := Vector2(177.0, 122.0)
	var aligned_hint := scene_rest_area.call(
		"_align_service_hint_with_hybrid_prop", 2, projected_hint
	) as Vector2
	var expected_prop_screen_x := (
		scene_rest_area.get_viewport().get_canvas_transform() * warehouse_prop.global_position
	).x
	failed = _check(
		is_equal_approx(aligned_hint.x, expected_prop_screen_x)
			and is_equal_approx(aligned_hint.y, projected_hint.y),
		"hybrid service hints must share the rendered facility's horizontal center"
	) or failed
	scene_rest_area.queue_free()
	var rest_area := RestAreaType.new()
	failed = _check(rest_area.call("_get_adjacent_zone_id", 4, Vector2i.UP) == 1, "up input must select the cell above") or failed
	failed = _check(rest_area.call("_get_adjacent_zone_id", 4, Vector2i.DOWN) == 7, "down input must select the cell below") or failed
	failed = _check(rest_area.call("_get_adjacent_zone_id", 4, Vector2i.LEFT) == 3, "left input must select the cell to the left") or failed
	failed = _check(rest_area.call("_get_adjacent_zone_id", 4, Vector2i.RIGHT) == 5, "right input must select the cell to the right") or failed
	failed = _check(rest_area.call("_get_adjacent_zone_id", 0, Vector2i.UP) == -1, "direction input must not leave the top grid edge") or failed
	failed = _check(rest_area.call("_get_adjacent_zone_id", 2, Vector2i.RIGHT) == -1, "direction input must not wrap to the next row") or failed
	PlayerData.run_completed_levels = 2
	failed = _check(not rest_area._is_zone_available(0), "purchase zone must be unavailable outside full-shop rounds") or failed
	failed = _check(not rest_area._zone_opens_interaction(0), "unavailable purchase zone must not open interaction") or failed
	PlayerData.run_completed_levels = 3
	failed = _check(rest_area._is_zone_available(0), "purchase zone must return on full-shop rounds") or failed
	PhaseManager.current_level = 3
	PhaseManager.phase = PhaseManager.SETTLEMENT
	PhaseManager.enter_protocol_selection()
	failed = _check(PhaseManager.is_rest_protocol_available(), "full-shop rounds must expose the rest protocol") or failed
	PhaseManager.enter_rest()
	failed = _check(PhaseManager.current_state() == PhaseManager.REST, "selecting the rest protocol must enter rest") or failed
	failed = _check(not PhaseManager.is_rest_protocol_available(), "a rest protocol cannot be consumed twice at the same level") or failed
	rest_area.free()

	var owner := VisualOwner.new()
	add_child(owner)
	var visuals := ZoneVisualsType.new()
	visuals.set_meta("hybrid_ground_active", true)
	owner.add_child(visuals)
	await get_tree().process_frame
	var shop_prop := visuals.get_node_or_null("HybridProp0") as Sprite2D
	failed = _check(shop_prop != null and not shop_prop.visible, "closed shop hybrid prop must be hidden") or failed
	owner.shop_available = true
	await get_tree().process_frame
	failed = _check(shop_prop != null and shop_prop.visible, "open shop hybrid prop must be restored") or failed

	var hint_owner := HintOwner.new()
	add_child(hint_owner)
	for label_name in ["MerchantHintLabel", "SmithHintLabel", "ModuleHintLabel", "BoardHintLabel", "BattleHintLabel"]:
		var label := Label.new()
		label.name = label_name
		hint_owner.add_child(label)
	var hint_presenter = HintPresenterType.new()
	hint_presenter.call(
		"setup",
		hint_owner,
		{"merchant": 0, "smith": 1, "module": 2, "board": 6, "center": 4},
		"Purchase", "Upgrade", "Warehouses", "Board", "Choose next protocol",
		Vector2.ZERO, Vector2(0.0, -14.0), 80, Color.CYAN, Color.GREEN
	)
	hint_presenter.call("setup_labels")
	hint_presenter.call("refresh")
	var merchant_hint := hint_owner.get_node("MerchantHintLabel") as Label
	failed = _check(
		merchant_hint.get_theme_font_size("font_size") == 16,
		"zone guidance must remain visually secondary to the main HUD"
	) or failed
	var smith_hint := hint_owner.get_node("SmithHintLabel") as Label
	var module_hint := hint_owner.get_node("ModuleHintLabel") as Label
	failed = _check(
		merchant_hint.size == Vector2(132.0, 36.0)
			and smith_hint.size == Vector2(132.0, 36.0)
			and module_hint.size == Vector2(132.0, 36.0),
		"service hints must keep compact fixed geometry"
	) or failed
	failed = _check(
		merchant_hint.position.x + merchant_hint.size.x < smith_hint.position.x
			and smith_hint.position.x + smith_hint.size.x < module_hint.position.x,
		"adjacent service hints must retain visible separation"
	) or failed
	failed = _check(
		merchant_hint.get_rect().get_center() == Vector2(80.0, 80.0)
			and smith_hint.get_rect().get_center() == Vector2(240.0, 80.0)
			and module_hint.get_rect().get_center() == Vector2(400.0, 80.0),
		"service hints must be centered on their service zones"
	) or failed
	failed = _check(not smith_hint.text.begins_with("^"), "upgrade hint must not expose an ASCII caret") or failed
	failed = _check(not module_hint.text.begins_with("[]"), "warehouse hint must not expose ASCII brackets") or failed
	var battle_hint := hint_owner.get_node("BattleHintLabel") as Label
	failed = _check(not battle_hint.text.begins_with(">"), "center action hint must not use a raw ASCII arrow") or failed
	failed = _check(
		battle_hint.text == LocalizationManager.tr_format(
			"ui.rest.zone.battle.prompt",
			{"input": LocalizationManager.tr_key("ui.controls.key.lmb", "LMB")},
			"[LMB] Choose Next Protocol"
		),
		"center action hint must identify the click input and protocol action"
	) or failed
	failed = _check(
		battle_hint.size.x >= 152.0 and battle_hint.size.x <= 220.0 and is_equal_approx(battle_hint.size.y, 30.0),
		"center action hint must use compact bounded geometry"
	) or failed
	hint_presenter.call("update_visibility")
	for child in hint_owner.get_children():
		failed = _check((child as Label).visible, "intro guidance must reveal every available zone label") or failed
	hint_owner.show_intro = false
	hint_presenter.call("update_visibility")
	failed = _check(not hint_owner.get_node("MerchantHintLabel").visible, "non-hovered labels must clear after intro") or failed
	failed = _check(hint_owner.get_node("SmithHintLabel").visible, "hovered label must remain visible after intro") or failed
	var hybrid_canvas := CanvasLayer.new()
	hint_owner.add_child(hybrid_canvas)
	smith_hint.reparent(hybrid_canvas, false)
	var projected_position := Vector2(713.0, 219.0)
	smith_hint.position = projected_position
	hint_presenter.call("refresh")
	failed = _check(
		smith_hint.position == projected_position,
		"status refresh must not overwrite a hybrid-projected service hint position"
	) or failed
	hint_owner.queue_free()

	PlayerData.run_completed_levels = previous_completed_levels
	PhaseManager.reset_runtime_state()
	if failed:
		push_error("REST_AREA_SHOP_VISIBILITY_TEST: FAIL")
		get_tree().quit(1)
		return
	print("REST_AREA_SHOP_VISIBILITY_TEST: PASS")
	get_tree().quit()

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
