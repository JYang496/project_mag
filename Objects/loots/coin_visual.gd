extends "res://Visual/Oblique/billboard_visual_2d.gd"


func _apply_compensation() -> void:
	super._apply_compensation()
	# The shared billboard handles screen height in the hybrid arena. Apply the
	# same height in ordinary 2D scenes without feeding it back into the anchor.
	if enabled and _get_hybrid_view() == null and is_inside_tree():
		global_position += get_viewport().get_canvas_transform().basis_xform_inv(screen_offset)
		_last_applied_transform = transform
