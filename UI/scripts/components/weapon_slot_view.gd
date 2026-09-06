extends RefCounted
class_name WeaponSlotView

const ICON_ROTATION := PI / 4.0
const MAINHAND_ICON_INSET := 3.0
const SUPPORT_ICON_INSET := 4.0
const WEAPON_DISK_CENTER := Vector2(38.0, 111.0)
const WEAPON_DISK_OFFSET := WEAPON_DISK_CENTER - Vector2(38.0, 36.0)
const SUPPORT_FRAME_MODULATE := Color(0.66, 0.76, 0.80, 0.78)
const SUPPORT_ICON_MODULATE := Color(0.80, 0.86, 0.88, 0.90)

var root: Control
var icon: TextureRect
var icon_shadow: TextureRect
var background: TextureRect
var frame: Control
var _missing_weapon_icon: Texture2D
var _is_mainhand := false
var _empty := true
var _content_cropped_textures: Dictionary = {}

func setup(slot_root: Control, missing_weapon_icon: Texture2D) -> void:
	root = slot_root
	root.draw.connect(_draw_empty_corners)
	_missing_weapon_icon = missing_weapon_icon
	icon = root.get_node_or_null("Icon") as TextureRect
	background = root.get_node_or_null("Background") as TextureRect
	if background != null:
		background.visible = false
	frame = preload("res://UI/scripts/components/weapon_role_frame.gd").new()
	frame.name = "RoleFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.position = WEAPON_DISK_OFFSET
	root.move_child(frame, 0)
	if icon != null:
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_ensure_icon_shadow()

func set_background(texture: Texture2D) -> void:
	if background != null:
		background.texture = texture

func set_role(is_mainhand: bool, mainhand_texture: Texture2D, support_texture: Texture2D) -> void:
	_is_mainhand = is_mainhand
	set_background(mainhand_texture if is_mainhand else support_texture)
	frame.set("selected", is_mainhand)
	if background != null:
		background.modulate = Color.WHITE if is_mainhand else SUPPORT_FRAME_MODULATE
	if icon == null:
		return
	_apply_weapon_icon_layout(icon.texture)
	icon.modulate = Color.WHITE if is_mainhand else SUPPORT_ICON_MODULATE


func set_ammo_state(visible_value: bool, progress: float, fill: Color, track: Color) -> void:
	if frame != null and frame.has_method("set_ammo_state"):
		frame.call("set_ammo_state", visible_value, progress, fill, track)

func show_empty() -> void:
	_empty = true
	root.queue_redraw()
	frame.visible = false
	if icon != null:
		icon.texture = null
		icon.visible = false
	if background != null:
		background.modulate = Color(0.48, 0.56, 0.62, 0.58)
	if icon_shadow != null:
		icon_shadow.texture = null
		icon_shadow.visible = false
	root.tooltip_text = ""

func show_weapon(weapon: Weapon) -> void:
	_empty = false
	root.queue_redraw()
	frame.visible = true
	if icon != null:
		icon.visible = true
		icon.texture = _resolve_weapon_texture(weapon)
		_apply_weapon_icon_layout(icon.texture)
		icon.modulate = Color.WHITE if _is_mainhand else SUPPORT_ICON_MODULATE
	if icon_shadow != null:
		icon_shadow.visible = true
		icon_shadow.texture = icon.texture if icon != null else null
	if background != null:
		background.modulate = Color.WHITE if _is_mainhand else SUPPORT_FRAME_MODULATE

func _draw_empty_corners() -> void:
	if not _empty:
		return
	var center := root.size * 0.5
	var color := Color(0.4, 0.5, 0.55, 0.4)
	root.draw_polyline(PackedVector2Array([center + Vector2(-7, -2), center + Vector2(-7, -7), center + Vector2(-2, -7)]), color, 1.0)
	root.draw_polyline(PackedVector2Array([center + Vector2(2, 7), center + Vector2(7, 7), center + Vector2(7, 2)]), color, 1.0)

func _ensure_icon_shadow() -> void:
	if icon == null or root == null:
		return
	icon_shadow = root.get_node_or_null("IconShadow") as TextureRect
	if icon_shadow != null:
		return
	icon_shadow = TextureRect.new()
	icon_shadow.name = "IconShadow"
	icon_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_shadow.set_anchors_preset(Control.PRESET_CENTER)
	icon_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon_shadow.modulate = Color(0.0, 0.02, 0.03, 0.82)
	root.add_child(icon_shadow)
	root.move_child(icon_shadow, icon.get_index())

func _apply_weapon_icon_layout(texture: Texture2D) -> void:
	if icon == null or root == null:
		return
	var icon_size := get_rotated_weapon_icon_size(texture, Vector2(58.0, 58.0), _is_mainhand)
	var offset := WEAPON_DISK_CENTER - root.size * 0.5
	_apply_icon_rect(icon, icon_size, offset)
	if icon_shadow != null:
		_apply_icon_rect(icon_shadow, icon_size, offset + Vector2(1.0, 1.0))

func get_rotated_weapon_icon_size(
	texture: Texture2D,
	slot_size: Vector2,
	is_mainhand: bool
) -> Vector2:
	var inset := MAINHAND_ICON_INSET if is_mainhand else SUPPORT_ICON_INSET
	var available_size := Vector2(
		maxf(slot_size.x - inset * 2.0, 1.0),
		maxf(slot_size.y - inset * 2.0, 1.0)
	)
	var aspect_ratio := 1.0
	if texture != null and texture.get_height() > 0:
		aspect_ratio = maxf(float(texture.get_width()) / float(texture.get_height()), 0.01)
	var cosine := absf(cos(ICON_ROTATION))
	var sine := absf(sin(ICON_ROTATION))
	var height_from_width := available_size.x / (aspect_ratio * cosine + sine)
	var height_from_height := available_size.y / (aspect_ratio * sine + cosine)
	var icon_height := maxf(floorf(minf(height_from_width, height_from_height)), 1.0)
	return Vector2(maxf(floorf(icon_height * aspect_ratio), 1.0), icon_height)

func _apply_icon_rect(target: TextureRect, icon_size: Vector2, offset: Vector2) -> void:
	if target == null:
		return
	target.offset_left = -icon_size.x * 0.5 + offset.x
	target.offset_top = -icon_size.y * 0.5 + offset.y
	target.offset_right = icon_size.x * 0.5 + offset.x
	target.offset_bottom = icon_size.y * 0.5 + offset.y
	target.pivot_offset = icon_size * 0.5
	target.rotation = ICON_ROTATION

func _resolve_weapon_texture(weapon: Variant) -> Texture2D:
	if is_instance_valid(weapon) and weapon.has_node("Sprite"):
		var sprite_node: Node = weapon.get_node_or_null("Sprite")
		if sprite_node != null:
			var sprite_texture: Variant = sprite_node.get("texture")
			if sprite_texture is Texture2D:
				return _crop_texture_to_content(sprite_texture as Texture2D)
	return _missing_weapon_icon

func _crop_texture_to_content(source: Texture2D) -> Texture2D:
	if source == null:
		return source
	var cache_key := source.get_rid()
	if _content_cropped_textures.has(cache_key):
		return _content_cropped_textures[cache_key] as Texture2D
	var image := source.get_image()
	if image == null or image.is_empty():
		_content_cropped_textures[cache_key] = source
		return source
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		_content_cropped_textures[cache_key] = source
		return source
	var texture_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var padded_rect := used_rect.grow(2).intersection(texture_rect)
	if padded_rect == texture_rect:
		_content_cropped_textures[cache_key] = source
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(padded_rect)
	_content_cropped_textures[cache_key] = atlas
	return atlas
