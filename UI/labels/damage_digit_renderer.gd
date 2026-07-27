extends RefCounted
class_name DamageDigitRenderer

const DIGIT_ATLAS := preload("res://UI/labels/assets/damage_digits_12px.png")
const ATLAS_GLYPHS := "0123456789+-!"
const GLYPH_CELL_SIZE := Vector2i(8, 12)
const GLYPH_ADVANCE_PX := 7

func measure(display_text: String, pixel_scale: int, outline_pixels: int) -> Vector2:
	var glyph_count := maxi(1, display_text.length())
	var text_width := (glyph_count - 1) * GLYPH_ADVANCE_PX + GLYPH_CELL_SIZE.x
	var padding := outline_pixels * 2
	return Vector2(
		(text_width + padding) * pixel_scale,
		(GLYPH_CELL_SIZE.y + padding) * pixel_scale
	)

func render(
	canvas: CanvasItem,
	display_text: String,
	pixel_scale: int,
	outline_pixels: int,
	font_color: Color,
	outline_color: Color,
	critical_color: Color
) -> void:
	var outline_step := pixel_scale
	var offsets: Array[Vector2] = [
		Vector2(-outline_step, 0.0),
		Vector2(outline_step, 0.0),
		Vector2(0.0, -outline_step),
		Vector2(0.0, outline_step),
	]
	if outline_pixels >= 2:
		offsets.append_array([
			Vector2(-outline_step, -outline_step),
			Vector2(outline_step, -outline_step),
			Vector2(-outline_step, outline_step),
			Vector2(outline_step, outline_step),
			Vector2(-outline_step * 2.0, 0.0),
			Vector2(outline_step * 2.0, 0.0),
			Vector2(0.0, -outline_step * 2.0),
			Vector2(0.0, outline_step * 2.0),
		])
	for offset in offsets:
		_render_pass(
			canvas,
			display_text,
			pixel_scale,
			outline_pixels,
			offset,
			outline_color,
			critical_color,
			false
		)
	_render_pass(
		canvas,
		display_text,
		pixel_scale,
		outline_pixels,
		Vector2.ZERO,
		font_color,
		critical_color,
		true
	)

func _render_pass(
	canvas: CanvasItem,
	display_text: String,
	pixel_scale: int,
	outline_pixels: int,
	offset: Vector2,
	color: Color,
	critical_color: Color,
	accent_critical: bool
) -> void:
	var x := float(outline_pixels * pixel_scale)
	var y := float(outline_pixels * pixel_scale)
	for character in display_text:
		var glyph_index := ATLAS_GLYPHS.find(character)
		if glyph_index < 0:
			continue
		var source_rect := Rect2(
			Vector2(glyph_index * GLYPH_CELL_SIZE.x, 0),
			Vector2(GLYPH_CELL_SIZE)
		)
		var destination_rect := Rect2(
			Vector2(x, y) + offset,
			Vector2(GLYPH_CELL_SIZE * pixel_scale)
		)
		var glyph_color := (
			critical_color
			if accent_critical and character == "!"
			else color
		)
		canvas.draw_texture_rect_region(
			DIGIT_ATLAS,
			destination_rect,
			source_rect,
			glyph_color
		)
		x += float(GLYPH_ADVANCE_PX * pixel_scale)
