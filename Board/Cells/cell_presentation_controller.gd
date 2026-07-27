extends RefCounted
class_name CellPresentationController

var visuals_visible := true
var default_terrain_only := false

func set_visuals_visible(
	value: bool,
	texture_root: CanvasItem,
	activation_visual: CanvasItem,
	task_marker_visual: CanvasItem,
	has_task_marker: bool
) -> void:
	visuals_visible = value
	apply_visibility(
		texture_root,
		activation_visual,
		task_marker_visual,
		has_task_marker
	)

func apply_visibility(
	texture_root: CanvasItem,
	activation_visual: CanvasItem,
	task_marker_visual: CanvasItem,
	has_task_marker: bool
) -> void:
	if texture_root != null:
		texture_root.visible = visuals_visible
	if activation_visual != null:
		activation_visual.visible = visuals_visible
	if task_marker_visual != null:
		task_marker_visual.visible = visuals_visible and has_task_marker

func configure_activation(
	activation_visual,
	board_enabled: bool,
	player_inside: bool,
	has_task: bool,
	cell_rect: Rect2
) -> void:
	if activation_visual == null or not is_instance_valid(activation_visual):
		return
	activation_visual.configure(board_enabled, player_inside, has_task, cell_rect)
	activation_visual.visible = visuals_visible

func should_render_task_marker(has_status: bool) -> bool:
	return visuals_visible and has_status

func resolve_profile_terrain(profile_terrain: int, none_terrain: int) -> int:
	return none_terrain if default_terrain_only else profile_terrain

func resolve_profile_aura(profile_aura_enabled: bool) -> bool:
	return false if default_terrain_only else profile_aura_enabled

func allows_aura_modules() -> bool:
	return not default_terrain_only
