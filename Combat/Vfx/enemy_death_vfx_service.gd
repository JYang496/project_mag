class_name EnemyDeathVfxService
extends Node

const MAX_ACTIVE_EFFECTS := 10
const UNIT_BILLBOARD_SCRIPT := preload("res://Visual/Oblique/unit_billboard_visual_2d.gd")
const DEATH_PROFILE := preload("res://Combat/Vfx/enemy_death_vfx_profile.gd")

var _entries: Array[Dictionary] = []
var _texture_cache: Dictionary = {}
var _serial := 0


static func ensure(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	var existing := tree.get_first_node_in_group(&"enemy_death_vfx_service")
	if existing != null:
		return existing
	var service = load("res://Combat/Vfx/enemy_death_vfx_service.gd").new()
	service.name = "EnemyDeathVfxService"
	service.add_to_group(&"enemy_death_vfx_service")
	tree.root.add_child(service)
	return service


func play(world_position: Vector2, profile: Resource) -> void:
	if profile == null:
		return
	var entry := _acquire_entry()
	var anchor := entry.get("anchor") as Node2D
	var core := entry.get("core") as Sprite2D
	var fragments := entry.get("fragments") as Sprite2D
	var debris := entry.get("debris") as Sprite2D
	var tween := entry.get("tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_serial += 1
	entry["serial"] = _serial
	entry["active"] = true
	entry["death_type"] = int(profile.get("death_type"))
	anchor.global_position = world_position
	anchor.visible = true
	var source_size := clampi(int(profile.get("source_size")), 32, 128)
	var effect_scale := clampf(float(profile.get("effect_scale")), 0.75, 2.5)
	var death_type := int(profile.get("death_type"))
	_configure_layer(core, _texture_for(source_size, 0, death_type), profile.get("core_color") as Color, effect_scale * 0.54)
	_configure_layer(fragments, _texture_for(source_size, 1, death_type), profile.get("debris_color") as Color, effect_scale * 0.72)
	_configure_layer(debris, _texture_for(source_size, 2, death_type), profile.get("debris_color") as Color, effect_scale * 0.62)
	debris.modulate.a = 0.0
	var duration := clampf(float(profile.get("duration_sec")), 0.20, 0.50)
	tween = create_tween()
	entry["tween"] = tween
	tween.set_parallel(true)
	_play_typed_motion(tween, core, fragments, debris, profile, effect_scale, duration)
	tween.finished.connect(_on_effect_finished.bind(anchor.get_instance_id(), _serial), CONNECT_ONE_SHOT)


func get_pool_metrics() -> Dictionary:
	var active := 0
	for entry in _entries:
		if bool(entry.get("active", false)):
			active += 1
	return {
		"pooled": _entries.size(),
		"active": active,
		"limit": MAX_ACTIVE_EFFECTS,
		"ground_effects": 0,
	}


func get_active_effect_types() -> Array[int]:
	var types: Array[int] = []
	for entry in _entries:
		if bool(entry.get("active", false)):
			types.append(int(entry.get("death_type", -1)))
	return types


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
	anchor.name = "EnemyDeathVfx%d" % _entries.size()
	var shadow := Node2D.new()
	shadow.name = "GroundShadow"
	anchor.add_child(shadow)
	var core := _create_billboard("BrightCore")
	var fragments := _create_billboard("FragmentBurst")
	var debris := _create_billboard("PixelDebris")
	anchor.add_child(core)
	anchor.add_child(fragments)
	anchor.add_child(debris)
	add_child(anchor)
	anchor.visible = false
	var entry := {"anchor": anchor, "core": core, "fragments": fragments, "debris": debris, "tween": null, "active": false, "serial": 0, "death_type": -1}
	_entries.append(entry)
	return entry


func _create_billboard(layer_name: String) -> Sprite2D:
	var visual := Sprite2D.new()
	visual.name = layer_name
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.set_script(UNIT_BILLBOARD_SCRIPT)
	return visual


func _configure_layer(visual: Sprite2D, texture: Texture2D, color: Color, scale_value: float) -> void:
	visual.texture = texture
	visual.modulate = color
	visual.scale = Vector2.ONE * scale_value
	visual.position = Vector2.ZERO
	visual.rotation = 0.0
	visual.visible = true


func _play_typed_motion(
	tween: Tween,
	core: Sprite2D,
	fragments: Sprite2D,
	debris: Sprite2D,
	profile: Resource,
	effect_scale: float,
	duration: float
) -> void:
	var death_type := int(profile.get("death_type"))
	var direction := profile.get("exit_direction") as Vector2
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	match death_type:
		DEATH_PROFILE.DeathType.ENERGY_COLLAPSE:
			tween.tween_property(core, "scale", Vector2.ONE * effect_scale * 0.12, duration * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(core, "modulate:a", 0.0, duration * 0.22).set_delay(duration * 0.70)
			tween.tween_property(fragments, "scale", Vector2.ONE * effect_scale * 0.24, duration * 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(fragments, "modulate:a", 0.0, duration * 0.30).set_delay(duration * 0.62)
			tween.tween_property(debris, "modulate:a", 0.36, duration * 0.16).set_delay(duration * 0.60)
			tween.tween_property(debris, "modulate:a", 0.0, duration * 0.22).set_delay(duration * 0.78)
		DEATH_PROFILE.DeathType.FIRE_BURNOUT:
			tween.tween_property(core, "scale", Vector2(effect_scale * 0.78, effect_scale * 0.46), duration * 0.74).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(core, "modulate", Color(0.18, 0.16, 0.15, 0.0), duration * 0.72).set_delay(duration * 0.18)
			tween.tween_property(fragments, "position:y", -14.0 * effect_scale, duration * 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(fragments, "modulate:a", 0.0, duration * 0.62).set_delay(duration * 0.28)
			tween.tween_property(debris, "position:y", -22.0 * effect_scale, duration * 0.72).set_delay(duration * 0.12)
			tween.tween_property(debris, "modulate:a", 0.58, duration * 0.14).set_delay(duration * 0.10)
			tween.tween_property(debris, "modulate:a", 0.0, duration * 0.48).set_delay(duration * 0.42)
		DEATH_PROFILE.DeathType.FREEZE_SHATTER:
			tween.tween_property(core, "modulate:a", 0.0, duration * 0.24).set_delay(duration * 0.24)
			tween.tween_property(fragments, "scale", Vector2.ONE * effect_scale * 1.18, duration * 0.72).set_delay(duration * 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(fragments, "rotation", 0.18, duration * 0.70).set_delay(duration * 0.24)
			tween.tween_property(fragments, "modulate:a", 0.0, duration * 0.48).set_delay(duration * 0.52)
			tween.tween_property(debris, "modulate:a", 0.42, duration * 0.12).set_delay(duration * 0.28)
			tween.tween_property(debris, "modulate:a", 0.0, duration * 0.46).set_delay(duration * 0.54)
		_:
			tween.tween_property(core, "scale", Vector2.ONE * effect_scale * 0.64, duration * 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(core, "modulate:a", 0.0, duration * 0.46).set_delay(duration * 0.12)
			tween.tween_property(fragments, "position", direction.normalized() * 18.0 * effect_scale, duration * 0.88).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(fragments, "scale", Vector2.ONE * effect_scale * 1.18, duration * 0.88).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(fragments, "modulate:a", 0.0, duration * 0.54).set_delay(duration * 0.40)
			tween.tween_property(debris, "modulate:a", 0.38, duration * 0.12).set_delay(duration * 0.18)
			tween.tween_property(debris, "modulate:a", 0.0, duration * 0.48).set_delay(duration * 0.48)


func _on_effect_finished(anchor_id: int, serial: int) -> void:
	for entry in _entries:
		var anchor := entry.get("anchor") as Node2D
		if anchor == null or anchor.get_instance_id() != anchor_id or int(entry.get("serial", -1)) != serial:
			continue
		entry["active"] = false
		entry["tween"] = null
		entry["death_type"] = -1
		anchor.visible = false
		for key in ["core", "fragments", "debris"]:
			var visual := entry.get(key) as Sprite2D
			visual.visible = false
			visual.modulate.a = 0.0
		return


func _texture_for(size: int, layer: int, death_type: int) -> Texture2D:
	var key := "%d:%d:%d" % [size, layer, death_type]
	if _texture_cache.has(key):
		return _texture_cache[key] as Texture2D
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2i(size / 2, size / 2)
	var unit := maxi(size / 32, 1)
	for y in range(size):
		for x in range(size):
			var delta := Vector2i(x, y) - center
			var alpha := _layer_alpha(delta, unit, layer, death_type)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


func _layer_alpha(delta: Vector2i, unit: int, layer: int, death_type: int) -> float:
	var distance := Vector2(delta).length()
	match layer:
		0:
			return 1.0 if distance <= float(3 * unit) else 0.0
		1:
			if death_type == DEATH_PROFILE.DeathType.FIRE_BURNOUT:
				return 1.0 if delta.y <= 2 * unit and delta.y >= -11 * unit and absi(delta.x) <= maxi(unit, (-delta.y + unit) / 4) else 0.0
			if death_type == DEATH_PROFILE.DeathType.FREEZE_SHATTER:
				var shard := absi(absi(delta.x) - absi(delta.y) * 2) <= unit and distance <= float(11 * unit)
				return 1.0 if shard else 0.0
			# Physical and energy deaths rely on the core flash and pixel debris.
			# Their former orthogonal/diagonal fragment layer produced a starburst.
			return 0.0
		_:
			var grid_x := posmod(delta.x / unit, 7)
			var grid_y := posmod(delta.y / unit, 5)
			return 0.7 if distance >= float(5 * unit) and distance <= float(12 * unit) and grid_x == 0 and grid_y == 0 else 0.0


func _exit_tree() -> void:
	for entry in _entries:
		var tween := entry.get("tween") as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	_entries.clear()
	_texture_cache.clear()
