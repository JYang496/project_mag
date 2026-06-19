extends RefCounted
class_name BattleCursorPresenter

const SPREAD_CURSOR_FALLBACK_RADIUS_PX := 10.0
const BATTLE_HARDWARE_CURSOR_SIZE := 32
const BATTLE_HARDWARE_CURSOR_COLOR := Color(0.9, 0.98, 1.0, 1.0)
const BATTLE_HARDWARE_CURSOR_RING_COLOR := Color(0.33, 0.66, 1.0, 0.38)
const BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR := Color(0.12, 0.2, 0.28, 0.9)

var owner_ui: Node
var spread_cursor_overlay
var cursor_reload_total_by_weapon: Dictionary = {}
var _battle_hardware_cursor_tex: Texture2D
var _battle_hardware_cursor_applied := false
var _battle_hardware_cursor_state_key := ""

func bind(owner: Node, overlay: Node) -> void:
	owner_ui = owner
	spread_cursor_overlay = overlay

func set_overlay(overlay: Node) -> void:
	spread_cursor_overlay = overlay

func update_spread_cursor_overlay(mouse_screen_override: Variant = null) -> void:
	if owner_ui == null or spread_cursor_overlay == null or not is_instance_valid(spread_cursor_overlay):
		return
	if not _should_use_battle_ring_cursor():
		clear_spread_cursor_ammo_progress()
		spread_cursor_overlay.visible = false
		return
	var viewport := owner_ui.get_viewport()
	if viewport == null:
		clear_spread_cursor_ammo_progress()
		spread_cursor_overlay.visible = false
		return
	var mouse_screen: Vector2 = mouse_screen_override if mouse_screen_override is Vector2 else viewport.get_mouse_position()
	spread_cursor_overlay.set_cursor_screen_position(mouse_screen)
	var main_weapon := _get_main_weapon_node()
	if main_weapon == null or not is_instance_valid(main_weapon):
		clear_spread_cursor_ammo_progress()
		refresh_battle_hardware_cursor_texture(false, 1.0)
		spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)
		spread_cursor_overlay.visible = false
		return
	update_battle_hardware_cursor_ammo_progress(main_weapon)
	var canvas_inv := viewport.get_canvas_transform().affine_inverse()
	var mouse_world := canvas_inv * mouse_screen
	var spread_enabled := false
	var spread_radius_world := 0.0
	if main_weapon.has_method("get_spread_preview_info_for_target"):
		var info_variant: Variant = main_weapon.call("get_spread_preview_info_for_target", mouse_world)
		if info_variant is Dictionary:
			var info := info_variant as Dictionary
			spread_enabled = bool(info.get("enabled", false))
			spread_radius_world = maxf(float(info.get("max_radius", 0.0)), 0.0)
	elif main_weapon.has_method("get_spread_preview_radius_for_target"):
		spread_radius_world = maxf(float(main_weapon.call("get_spread_preview_radius_for_target", mouse_world)), 0.0)
		spread_enabled = spread_radius_world > 0.0
	if spread_enabled and spread_radius_world > 0.0:
		spread_cursor_overlay.set_world_anchor_and_radius(mouse_world, spread_radius_world)
		spread_cursor_overlay.visible = true
		return
	spread_cursor_overlay.set_fallback_screen_radius(SPREAD_CURSOR_FALLBACK_RADIUS_PX)
	spread_cursor_overlay.visible = false

func _get_main_weapon_node() -> Node:
	if PlayerData.player != null and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("get_main_weapon"):
		var player_weapon_variant: Variant = PlayerData.player.call("get_main_weapon")
		var player_weapon := player_weapon_variant as Node
		if player_weapon != null and is_instance_valid(player_weapon):
			return player_weapon
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon_variant: Variant = PlayerData.player_weapon_list[idx]
	var weapon_node := weapon_variant as Node
	if weapon_node == null or not is_instance_valid(weapon_node):
		return null
	return weapon_node

func update_battle_hardware_cursor_ammo_progress(main_weapon: Node) -> void:
	if main_weapon == null or not is_instance_valid(main_weapon):
		refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	if not main_weapon.has_method("get_ammo_status"):
		refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var status_variant: Variant = main_weapon.call("get_ammo_status")
	if not (status_variant is Dictionary):
		refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var status := status_variant as Dictionary
	if not bool(status.get("enabled", false)):
		refresh_battle_hardware_cursor_texture(false, 1.0)
		return
	var max_ammo: int = max(1, int(status.get("max", 0)))
	var current_ammo: int = clampi(int(status.get("current", 0)), 0, max_ammo)
	var is_reloading: bool = bool(status.get("is_reloading", false))
	var reload_left: float = maxf(float(status.get("reload_left", 0.0)), 0.0)
	var weapon_id: int = main_weapon.get_instance_id()
	var progress: float = 1.0
	if is_reloading:
		var tracked_total := float(cursor_reload_total_by_weapon.get(weapon_id, 0.0))
		if tracked_total <= 0.0:
			tracked_total = reload_left
		tracked_total = maxf(tracked_total, reload_left)
		cursor_reload_total_by_weapon[weapon_id] = tracked_total
		if tracked_total <= 0.0:
			progress = 0.0
		else:
			progress = clampf(1.0 - (reload_left / tracked_total), 0.0, 1.0)
	else:
		cursor_reload_total_by_weapon.erase(weapon_id)
		progress = clampf(float(current_ammo) / float(max_ammo), 0.0, 1.0)
	refresh_battle_hardware_cursor_texture(true, progress)

func apply_battle_hardware_cursor() -> void:
	if _battle_hardware_cursor_applied:
		return
	if not refresh_battle_hardware_cursor_texture(false, 1.0):
		return
	_set_custom_cursor_texture(_battle_hardware_cursor_tex)
	_battle_hardware_cursor_applied = true

func refresh_battle_hardware_cursor_texture(ammo_visible: bool, ammo_progress: float) -> bool:
	var progress_bucket := clampi(int(round(clampf(ammo_progress, 0.0, 1.0) * 100.0)), 0, 100)
	var state_key := "%s:%d" % [str(ammo_visible), progress_bucket]
	if _battle_hardware_cursor_tex != null and state_key == _battle_hardware_cursor_state_key:
		return true
	_battle_hardware_cursor_tex = build_battle_hardware_cursor_texture(ammo_visible, float(progress_bucket) / 100.0)
	_battle_hardware_cursor_state_key = state_key
	if _battle_hardware_cursor_tex == null:
		return false
	if _battle_hardware_cursor_applied:
		_set_custom_cursor_texture(_battle_hardware_cursor_tex)
	return true

func clear_battle_hardware_cursor() -> void:
	if not _battle_hardware_cursor_applied:
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(null, shape)
	_battle_hardware_cursor_applied = false
	_battle_hardware_cursor_state_key = ""

func build_battle_hardware_cursor_texture(ammo_visible: bool = false, ammo_progress: float = 1.0) -> Texture2D:
	var size: int = maxi(12, BATTLE_HARDWARE_CURSOR_SIZE)
	var center := int(round(float(size) * 0.5))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := BATTLE_HARDWARE_CURSOR_COLOR
	var ring_radius := clampi(int(round(SPREAD_CURSOR_FALLBACK_RADIUS_PX)), 4, maxi(4, center - 3))
	var center_v := Vector2(center, center)
	var diamond := [
		center_v + Vector2(0.0, -ring_radius),
		center_v + Vector2(ring_radius, 0.0),
		center_v + Vector2(0.0, ring_radius),
		center_v + Vector2(-ring_radius, 0.0),
	]
	_draw_image_polyline(image, diamond, BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_polyline(image, diamond, BATTLE_HARDWARE_CURSOR_RING_COLOR, 1)
	if ammo_visible:
		_draw_image_diamond_progress(image, diamond, clampf(ammo_progress, 0.0, 1.0), c, 2)
	_draw_image_line(image, Vector2(center - 4, center), Vector2(center + 4, center), BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_line(image, Vector2(center, center - 4), Vector2(center, center + 4), BATTLE_HARDWARE_CURSOR_OUTLINE_COLOR, 3)
	_draw_image_line(image, Vector2(center - 4, center), Vector2(center + 4, center), c, 1)
	_draw_image_line(image, Vector2(center, center - 4), Vector2(center, center + 4), c, 1)
	return ImageTexture.create_from_image(image)

func clear_spread_cursor_ammo_progress() -> void:
	if spread_cursor_overlay != null and is_instance_valid(spread_cursor_overlay):
		spread_cursor_overlay.clear_ammo_progress()
	cursor_reload_total_by_weapon.clear()

func _set_custom_cursor_texture(texture: Texture2D) -> void:
	var hotspot := Vector2(BATTLE_HARDWARE_CURSOR_SIZE * 0.5, BATTLE_HARDWARE_CURSOR_SIZE * 0.5)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_WAIT]:
		Input.set_custom_mouse_cursor(texture, shape, hotspot)

func _draw_image_diamond_progress(image: Image, points: Array, progress: float, color: Color, width: int = 1) -> void:
	if points.size() < 2 or progress <= 0.0:
		return
	var ordered := [points[0], points[3], points[2], points[1], points[0]]
	var total_len := 0.0
	for index in range(ordered.size() - 1):
		total_len += (ordered[index] as Vector2).distance_to(ordered[index + 1] as Vector2)
	var remaining := total_len * clampf(progress, 0.0, 1.0)
	for index in range(ordered.size() - 1):
		if remaining <= 0.0:
			return
		var from_point := ordered[index] as Vector2
		var to_point := ordered[index + 1] as Vector2
		var segment_len := from_point.distance_to(to_point)
		if remaining >= segment_len:
			_draw_image_line(image, from_point, to_point, color, width)
			remaining -= segment_len
			continue
		var partial_to := from_point.lerp(to_point, remaining / maxf(segment_len, 0.0001))
		_draw_image_line(image, from_point, partial_to, color, width)
		return

func _draw_image_polyline(image: Image, points: Array, color: Color, width: int = 1) -> void:
	if points.size() < 2:
		return
	for index in range(points.size()):
		var from_point := points[index] as Vector2
		var to_point := points[(index + 1) % points.size()] as Vector2
		_draw_image_line(image, from_point, to_point, color, width)

func _draw_image_line(image: Image, from_point: Vector2, to_point: Vector2, color: Color, width: int = 1) -> void:
	var steps := maxi(int(ceil(from_point.distance_to(to_point))), 1)
	var radius := maxi(int(floor(float(width) * 0.5)), 0)
	for step in range(steps + 1):
		var point := from_point.lerp(to_point, float(step) / float(steps))
		_draw_image_point(image, point, color, radius)

func _draw_image_point(image: Image, point: Vector2, color: Color, radius: int) -> void:
	var px := int(round(point.x))
	var py := int(round(point.y))
	for y in range(py - radius, py + radius + 1):
		for x in range(px - radius, px + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			image.set_pixel(x, y, color)

func _should_use_battle_ring_cursor() -> bool:
	if owner_ui == null:
		return false
	if owner_ui.has_method("_should_use_battle_ring_cursor"):
		return bool(owner_ui.call("_should_use_battle_ring_cursor"))
	return false
