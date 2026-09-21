extends Resource
## Presentation only; never changes contract rules or offer weights.
@export var entries: Dictionary = {}
@export var textures: Dictionary = {}
@export var slice_margin: int = 24

func entry(id: String) -> Dictionary:
	return entries.get(id, {})

func texture(key: String) -> Texture2D:
	return load_texture(str(textures.get(key, "")))

func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D

func style(key: String, tint: Color = Color.WHITE, center: bool = true) -> StyleBox:
	var image := texture(key)
	if image == null:
		# Deliberate emergency fallback only. Text and input remain usable.
		var fallback := StyleBoxFlat.new()
		fallback.bg_color = Color(0.035, 0.065, 0.085, 0.98) if center else Color.TRANSPARENT
		fallback.border_color = tint
		fallback.set_border_width_all(2)
		return fallback
	var box := StyleBoxTexture.new()
	box.texture = image
	box.modulate_color = tint
	box.draw_center = center
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 16 if key == "button" else slice_margin)
		box.set_content_margin(side, 0)
	return box

func progress_style(filled: bool, tint: Color = Color.WHITE) -> StyleBox:
	var box := style("frame", tint)
	if box is StyleBoxTexture:
		box.region_rect = Rect2(50, 1, 8, 2) if filled else Rect2(50, 50, 8, 2)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, 0)
	return box
