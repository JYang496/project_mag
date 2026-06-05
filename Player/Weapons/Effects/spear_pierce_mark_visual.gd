extends Sprite2D

var _mark_id: StringName = StringName()


func configure(icon: Texture2D, mark_id: StringName, size_px: float, vertical_offset: float) -> void:
	texture = icon
	_mark_id = mark_id
	position = Vector2(0.0, vertical_offset)
	z_index = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture == null:
		scale = Vector2.ONE
		return
	var texture_size := texture.get_size()
	var longest_side := maxf(texture_size.x, texture_size.y)
	var resolved_scale := maxf(size_px, 1.0) / maxf(longest_side, 1.0)
	scale = Vector2.ONE * resolved_scale


func _process(_delta: float) -> void:
	var target := get_parent()
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	if _mark_id == StringName():
		queue_free()
		return
	if not target.has_method("has_mark") or not bool(target.call("has_mark", _mark_id)):
		queue_free()
