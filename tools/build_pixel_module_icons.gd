extends SceneTree

## Converts every module SVG into a deterministic 32x32 hard-edged pixel icon.
##
## The SVG artwork is retained as the editable source. Runtime scenes use the
## generated PNGs under asset/images/modules/pixel/.

const SOURCE_DIR := "res://asset/images/modules"
const OUTPUT_DIR := "res://asset/images/modules/pixel"
const ICON_SIZE := Vector2i(32, 32)
const GLYPH_SIZE := Vector2i(22, 22)
const GLYPH_OFFSET := Vector2i(5, 5)
const HANDCRAFTED_ICONS := {
	"wmod_bullet_size_stat.svg": true,
	"wmod_damage_up_stat.svg": true,
	"wmod_expanded_magazine.svg": true,
	"wmod_fast_reload.svg": true,
	"wmod_lifesteal_on_hit.svg": true,
	"wmod_pierce_stat.svg": true,
	"wmod_projectile_speed_stat.svg": true,
	"wmod_reload_speed_link.svg": true,
}

const INK := Color8(5, 10, 18)
const EDGE := Color8(57, 153, 184)
const EDGE_LIGHT := Color8(132, 230, 242)
const PANEL := Color8(9, 18, 28)


func _initialize() -> void:
	var source_dir := DirAccess.open(SOURCE_DIR)
	if source_dir == null:
		push_error("Unable to open module icon source directory: %s" % SOURCE_DIR)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var filenames := source_dir.get_files()
	filenames.sort()
	var built := 0
	for filename in filenames:
		if filename.get_extension().to_lower() != "svg":
			continue
		if HANDCRAFTED_ICONS.has(filename):
			continue
		var source_path := SOURCE_DIR.path_join(filename)
		var texture := load(source_path) as Texture2D
		if texture == null:
			push_error("Unable to load module SVG: %s" % source_path)
			quit(1)
			return
		var glyph := texture.get_image()
		glyph.resize(GLYPH_SIZE.x, GLYPH_SIZE.y, Image.INTERPOLATE_NEAREST)
		_harden_pixels(glyph)

		var icon := _build_frame()
		icon.blend_rect(glyph, Rect2i(Vector2i.ZERO, GLYPH_SIZE), GLYPH_OFFSET)
		var output_path := OUTPUT_DIR.path_join(filename.get_basename() + ".png")
		var error := icon.save_png(output_path)
		if error != OK:
			push_error("Unable to save module pixel icon: %s (%s)" % [output_path, error])
			quit(1)
			return
		built += 1

	print("Built %d pixel module icons." % built)
	quit(0)


func _build_frame() -> Image:
	var image := Image.create(ICON_SIZE.x, ICON_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_fill_rect(image, Rect2i(0, 0, 32, 32), INK)
	_fill_rect(image, Rect2i(2, 2, 28, 28), EDGE)
	_fill_rect(image, Rect2i(4, 4, 24, 24), PANEL)
	for corner in [Vector2i(2, 2), Vector2i(25, 2), Vector2i(2, 25), Vector2i(25, 25)]:
		_fill_rect(image, Rect2i(corner, Vector2i(5, 5)), EDGE_LIGHT)
	return image


func _harden_pixels(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			image.set_pixel(
				x,
				y,
				Color8(
					_quantize_channel(color.r8),
					_quantize_channel(color.g8),
					_quantize_channel(color.b8),
					255
				)
			)


func _quantize_channel(value: int) -> int:
	return clampi(roundi(float(value) / 17.0) * 17, 0, 255)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)
