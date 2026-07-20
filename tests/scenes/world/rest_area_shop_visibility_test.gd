extends Node

const RestAreaType := preload("res://World/rest_area.gd")
const ZoneVisualsType := preload("res://World/rest_area_zone_visuals.gd")

class VisualOwner:
	extends Node2D
	var shop_available := false

	func _is_zone_available(zone_id: int) -> bool:
		return zone_id != 0 or shop_available

	func _get_zone_rect_local(zone_id: int) -> Rect2:
		return Rect2(Vector2(zone_id % 3, zone_id / 3) * 100.0, Vector2(100.0, 100.0))

func _ready() -> void:
	var failed := false
	var previous_completed_levels := PlayerData.run_completed_levels
	var rest_area := RestAreaType.new()
	PlayerData.run_completed_levels = 2
	failed = _check(not rest_area._is_zone_available(0), "purchase zone must be unavailable outside full-shop rounds") or failed
	failed = _check(not rest_area._zone_opens_interaction(0), "unavailable purchase zone must not open interaction") or failed
	PlayerData.run_completed_levels = 3
	failed = _check(rest_area._is_zone_available(0), "purchase zone must return on full-shop rounds") or failed
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

	PlayerData.run_completed_levels = previous_completed_levels
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
