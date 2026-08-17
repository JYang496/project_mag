class_name CombatHitVfxService
extends Node

const MAX_ACTIVE_EFFECTS := 32
const EFFECT_TEXTURE_SIZE := 32
const EFFECT_SCALE_MULTIPLIER := 0.75
const UNIT_BILLBOARD_SCRIPT := preload("res://Visual/Oblique/unit_billboard_visual_2d.gd")

var _entries: Array[Dictionary] = []
var _texture_cache: Dictionary = {}
var _serial := 0


static func ensure(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	var existing := tree.get_first_node_in_group(&"combat_hit_vfx_service")
	if existing != null:
		return existing
	var service = load("res://Combat/Vfx/combat_hit_vfx_service.gd").new()
	service.name = "CombatHitVfxService"
	service.add_to_group(&"combat_hit_vfx_service")
	tree.root.add_child(service)
	return service


func play(world_position: Vector2, profile: Resource, hit_direction: Vector2 = Vector2.RIGHT) -> void:
	if profile == null:
		return
	var entry := _acquire_entry()
	if entry.is_empty():
		return
	var anchor := entry.get("anchor") as Node2D
	var visual := entry.get("visual") as Sprite2D
	var tween := entry.get("tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_serial += 1
	entry["serial"] = _serial
	entry["active"] = true
	anchor.global_position = world_position
	anchor.visible = true
	visual.texture = _texture_for_pattern(profile.texture_pattern)
	visual.mode = 1 # BillboardVisual2D.BillboardMode.DIRECTIONAL
	visual.set_world_direction(hit_direction if hit_direction.length_squared() > 0.0001 else Vector2.RIGHT)
	visual.visible = true
	visual.modulate = profile.impact_color
	visual.modulate.a = 1.0
	visual.scale = Vector2.ONE * profile.impact_scale * 0.72 * EFFECT_SCALE_MULTIPLIER
	var duration := clampf(profile.duration_sec, 0.08, 0.24)
	tween = create_tween()
	entry["tween"] = tween
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE * profile.impact_scale * 1.18 * EFFECT_SCALE_MULTIPLIER, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_effect_finished.bind(anchor.get_instance_id(), _serial), CONNECT_ONE_SHOT)


func get_pool_metrics() -> Dictionary:
	var active := 0
	for entry in _entries:
		if bool(entry.get("active", false)):
			active += 1
	return {"pooled": _entries.size(), "active": active, "limit": MAX_ACTIVE_EFFECTS}


func _acquire_entry() -> Dictionary:
	for entry in _entries:
		if not bool(entry.get("active", false)):
			return entry
	if _entries.size() < MAX_ACTIVE_EFFECTS:
		return _create_entry()
	var oldest := _entries[0]
	for entry in _entries:
		if int(entry.get("serial", 0)) < int(oldest.get("serial", 0)):
			oldest = entry
	return oldest


func _create_entry() -> Dictionary:
	var anchor := Node2D.new()
	anchor.name = "HitImpactVfx%d" % _entries.size()
	var shadow := Node2D.new()
	shadow.name = "GroundShadow"
	anchor.add_child(shadow)
	var visual := Sprite2D.new()
	visual.name = "ImpactBillboard"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.set_script(UNIT_BILLBOARD_SCRIPT)
	anchor.add_child(visual)
	add_child(anchor)
	anchor.visible = false
	var entry := {"anchor": anchor, "visual": visual, "tween": null, "active": false, "serial": 0}
	_entries.append(entry)
	return entry


func _on_effect_finished(anchor_id: int, serial: int) -> void:
	for entry in _entries:
		var anchor := entry.get("anchor") as Node2D
		if anchor == null or anchor.get_instance_id() != anchor_id or int(entry.get("serial", -1)) != serial:
			continue
		var visual := entry.get("visual") as Sprite2D
		entry["active"] = false
		entry["tween"] = null
		anchor.visible = false
		visual.visible = false
		visual.modulate.a = 0.0
		return


func _texture_for_pattern(pattern: int) -> Texture2D:
	var safe_pattern := clampi(pattern, 0, 2)
	if _texture_cache.has(safe_pattern):
		return _texture_cache[safe_pattern] as Texture2D
	var image := Image.create(EFFECT_TEXTURE_SIZE, EFFECT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2i(EFFECT_TEXTURE_SIZE / 2, EFFECT_TEXTURE_SIZE / 2)
	var half_length: int = int([7, 11, 9][safe_pattern])
	for y in range(EFFECT_TEXTURE_SIZE):
		for x in range(EFFECT_TEXTURE_SIZE):
			var delta := Vector2i(x, y) - center
			var alpha := 0.0
			var distance_from_tip := half_length - absi(delta.x)
			if distance_from_tip >= 0 and absi(delta.y) <= 1:
				alpha = 1.0 if delta.y == 0 or distance_from_tip >= 2 else 0.72
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[safe_pattern] = texture
	return texture


func _exit_tree() -> void:
	for entry in _entries:
		var tween := entry.get("tween") as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_entries.clear()
	_texture_cache.clear()
