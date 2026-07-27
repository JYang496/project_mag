extends RefCounted
class_name UiLayoutPolicy

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")

const REFERENCE_VIEWPORT := Vector2(1280.0, 720.0)
const MANAGEMENT_TARGET_SIZE := Vector2(1000.0, 600.0)
const PRIMARY_MENU_BASE_WIDTH := 360.0
const PRIMARY_MENU_MIN_HEIGHT := 320.0
const PRIMARY_MENU_HEADER_HEIGHT := 104.0
const PRIMARY_MENU_ENTRY_PITCH := 58.0
const PRIMARY_MENU_FOOTER_SPACE := 28.0
const HUD_LEFT_WIDTH := 340.0
const HUD_RIGHT_WIDTH := 320.0


static func scale_for_viewport(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(
		minf(
			viewport_size.x / REFERENCE_VIEWPORT.x,
			viewport_size.y / REFERENCE_VIEWPORT.y
		),
		1.0,
		1.5
	)


static func safe_margin(viewport_size: Vector2) -> Vector2:
	var scale := scale_for_viewport(viewport_size)
	return Vector2(
		roundf(float(TOKENS.SPACE_5) * scale),
		roundf(float(TOKENS.SPACE_5) * scale)
	)


static func fit_centered_rect(viewport_size: Vector2, target_size: Vector2) -> Rect2:
	var margin := safe_margin(viewport_size)
	var available := Vector2(
		maxf(viewport_size.x - margin.x * 2.0, 0.0),
		maxf(viewport_size.y - margin.y * 2.0, 0.0)
	)
	var size := Vector2(
		minf(target_size.x, available.x),
		minf(target_size.y, available.y)
	)
	return Rect2((viewport_size - size) * 0.5, size)


static func management_panel_rect(viewport_size: Vector2) -> Rect2:
	return fit_centered_rect(viewport_size, MANAGEMENT_TARGET_SIZE)


static func primary_menu_rect(viewport_size: Vector2, entry_count: int = 2) -> Rect2:
	var margin := safe_margin(viewport_size)
	var scale := scale_for_viewport(viewport_size)
	var desired_height := maxf(
		PRIMARY_MENU_MIN_HEIGHT,
		PRIMARY_MENU_HEADER_HEIGHT
			+ PRIMARY_MENU_ENTRY_PITCH * float(maxi(entry_count, 1))
			+ PRIMARY_MENU_FOOTER_SPACE
	)
	var available := Vector2(
		maxf(viewport_size.x - margin.x * 2.0, 0.0),
		maxf(viewport_size.y - margin.y * 2.0, 0.0)
	)
	var size := Vector2(
		minf(roundf(PRIMARY_MENU_BASE_WIDTH * scale), available.x),
		minf(roundf(desired_height * scale), available.y)
	)
	return Rect2(
		Vector2(margin.x, maxf(margin.y, (viewport_size.y - size.y) * 0.5)),
		size
	)


static func hud_left_lane(viewport_size: Vector2) -> Rect2:
	var margin := safe_margin(viewport_size)
	return Rect2(
		margin,
		Vector2(HUD_LEFT_WIDTH, maxf(viewport_size.y - margin.y * 2.0, 0.0))
	)


static func hud_right_lane(viewport_size: Vector2) -> Rect2:
	var margin := safe_margin(viewport_size)
	return Rect2(
		Vector2(viewport_size.x - margin.x - HUD_RIGHT_WIDTH, margin.y),
		Vector2(HUD_RIGHT_WIDTH, maxf(viewport_size.y - margin.y * 2.0, 0.0))
	)


static func hud_center_safe_rect(viewport_size: Vector2) -> Rect2:
	var horizontal_inset := maxf(viewport_size.x * 0.28, HUD_LEFT_WIDTH + safe_margin(viewport_size).x)
	var vertical_inset := viewport_size.y * 0.19
	return Rect2(
		Vector2(horizontal_inset, vertical_inset),
		Vector2(
			maxf(viewport_size.x - horizontal_inset * 2.0, 0.0),
			maxf(viewport_size.y - vertical_inset * 2.0, 0.0)
		)
	)

