extends RefCounted
class_name UiDesignTokens

## Shared visual and interaction tokens for the player-facing UI.
##
## Keep business screens independent, but build them from this vocabulary so
## purchase, upgrade, warehouse, battle HUD, and modal flows feel related.

const COLOR_CANVAS := Color(0.012, 0.020, 0.030, 1.0)
const COLOR_SURFACE := Color(0.035, 0.052, 0.071, 0.97)
const COLOR_SURFACE_ELEVATED := Color(0.055, 0.078, 0.102, 0.98)
const COLOR_SURFACE_INTERACTIVE := Color(0.075, 0.105, 0.132, 1.0)
const COLOR_BORDER := Color(0.20, 0.36, 0.46, 0.92)
const COLOR_BORDER_STRONG := Color(0.34, 0.66, 0.76, 1.0)
const COLOR_ACCENT_SYSTEM := Color(0.34, 0.78, 0.88, 1.0)
const COLOR_ACCENT_ACTION := Color(0.96, 0.70, 0.22, 1.0)
const COLOR_POSITIVE := Color(0.36, 0.84, 0.60, 1.0)
const COLOR_WARNING := Color(0.98, 0.58, 0.18, 1.0)
const COLOR_DANGER := Color(0.94, 0.30, 0.28, 1.0)
const COLOR_TEXT_PRIMARY := Color(0.93, 0.97, 0.98, 1.0)
const COLOR_TEXT_SECONDARY := Color(0.69, 0.78, 0.83, 1.0)
const COLOR_TEXT_MUTED := Color(0.45, 0.55, 0.61, 1.0)
const COLOR_SCRIM := Color(0.0, 0.0, 0.0, 0.70)

const FONT_CAPTION := 12
const FONT_LABEL := 14
const FONT_BODY := 16
const FONT_BUTTON := 17
const FONT_TITLE := 24
const FONT_DISPLAY := 32

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32

const BORDER_THIN := 1
const BORDER_STRONG := 2
const RADIUS_SMALL := 2
const RADIUS_PANEL := 4
const BUTTON_HEIGHT := 48.0
const BUTTON_HEIGHT_LARGE := 54.0
const TOUCH_TARGET_MIN := 44.0

const MOTION_FAST := 0.12
const MOTION_NORMAL := 0.20
const MOTION_SLOW := 0.34


static func make_panel_style(elevated: bool = false, accent: Color = COLOR_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE_ELEVATED if elevated else COLOR_SURFACE
	style.border_color = accent
	style.set_border_width_all(BORDER_STRONG)
	style.set_corner_radius_all(RADIUS_PANEL)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 6
	style.shadow_offset = Vector2(4.0, 4.0)
	return style


static func make_button_style(
	background: Color,
	border: Color,
	hover_amount: float = 0.10
) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.set_border_width_all(BORDER_THIN)
	normal.set_corner_radius_all(RADIUS_SMALL)
	normal.content_margin_left = SPACE_4
	normal.content_margin_right = SPACE_4
	normal.content_margin_top = SPACE_2
	normal.content_margin_bottom = SPACE_2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(hover_amount)
	hover.border_color = border.lightened(0.10)
	hover.set_border_width_all(BORDER_STRONG)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.12)
	pressed.border_color = border
	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = COLOR_ACCENT_ACTION
	return {
		"normal": normal,
		"hover": hover,
		"pressed": pressed,
		"focus": focus,
	}


static func style_label(
	label: Label,
	font_size: int = FONT_BODY,
	color: Color = COLOR_TEXT_PRIMARY
) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.03, 0.86))
	label.add_theme_constant_override("outline_size", 1)

