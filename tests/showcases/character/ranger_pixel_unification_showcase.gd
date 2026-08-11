extends Control

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const RANGER_SCENE := preload("res://Player/Mechas/scenes/ranger.tscn")
const HEAVY_ASSAULT_SCENE := preload("res://Player/Mechas/scenes/heavy_assault.tscn")
const MELEE_SCENE := preload("res://Player/Mechas/scenes/melee.tscn")
const COLLECTOR_SCENE := preload("res://Player/Mechas/scenes/collector.tscn")
const TURRET_SCENE := preload("res://Player/Mechas/scenes/turret.tscn")

const EXPECTED_FRAME_SIZE := Vector2(128.0, 128.0)
const RUNTIME_FOOTPRINT := Vector2(96.0, 96.0)
const DISPLAY_SCALE := 0.75

var _failed := false


func _ready() -> void:
	_build_ranger_gallery()
	_build_unchanged_mecha_comparison()
	await get_tree().process_frame
	_validate_showcase()
	if DisplayServer.get_name() == "headless":
		print("FAIL Ranger pixel unification showcase" if _failed else "PASS Ranger pixel unification showcase")
		await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _build_ranger_gallery() -> void:
	var ranger := RANGER_SCENE.instantiate()
	var idle_top := ranger.get("mecha_idle_top_texture") as Texture2D
	var idle_bottom := ranger.get("mecha_idle_bottom_texture") as Texture2D
	var move_frames := ranger.get("mecha_move_sprite_frames") as SpriteFrames
	ranger.free()

	%RangerGallery.add_child(_make_static_card("正面待机", "idle_bottom · 96 px", idle_bottom))
	%RangerGallery.add_child(_make_static_card("背面待机", "idle_top · 96 px", idle_top))
	%RangerGallery.add_child(_make_animated_card("正面磁悬浮移动", "8 帧 · 10 FPS · 循环", move_frames, &"move_bottom"))
	%RangerGallery.add_child(_make_animated_card("背面磁悬浮移动", "8 帧 · 10 FPS · 循环", move_frames, &"move_top"))


func _build_unchanged_mecha_comparison() -> void:
	var entries: Array[Dictionary] = [
		{"name": "重型突击", "scene": HEAVY_ASSAULT_SCENE},
		{"name": "近战", "scene": MELEE_SCENE},
		{"name": "收集者", "scene": COLLECTOR_SCENE},
		{"name": "炮台", "scene": TURRET_SCENE},
	]
	for entry in entries:
		var instance := (entry.scene as PackedScene).instantiate()
		var texture := instance.get("mecha_idle_bottom_texture") as Texture2D
		instance.free()
		%OtherMechaGallery.add_child(_make_static_card(str(entry.name), "共享资源 · 未改动", texture, Vector2(250.0, 178.0)))


func _make_static_card(title: String, detail: String, texture: Texture2D, minimum_size := Vector2(282.0, 220.0)) -> PanelContainer:
	var card := _make_card_shell(title, detail, minimum_size)
	var stage := card.get_meta("stage") as Control
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(minimum_size.x * 0.5, 62.0)
	sprite.scale = Vector2.ONE * DISPLAY_SCALE
	stage.add_child(sprite)
	return card


func _make_animated_card(title: String, detail: String, frames: SpriteFrames, animation_name: StringName) -> PanelContainer:
	var card := _make_card_shell(title, detail, Vector2(282.0, 220.0))
	var stage := card.get_meta("stage") as Control
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = animation_name
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(141.0, 62.0)
	sprite.scale = Vector2.ONE * DISPLAY_SCALE
	stage.add_child(sprite)
	sprite.play()
	return card


func _make_card_shell(title: String, detail: String, minimum_size: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d26")
	style.border_color = Color("2c6575")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("91e7f5"))
	title_label.add_theme_font_size_override("font_size", 16)
	column.add_child(title_label)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(minimum_size.x, 124.0)
	column.add_child(stage)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_color_override("font_color", Color("9eacb3"))
	column.add_child(detail_label)
	card.set_meta("stage", stage)
	return card


func _validate_showcase() -> void:
	var ranger := RANGER_SCENE.instantiate()
	var idle_top := ranger.get("mecha_idle_top_texture") as Texture2D
	var idle_bottom := ranger.get("mecha_idle_bottom_texture") as Texture2D
	var frames := ranger.get("mecha_move_sprite_frames") as SpriteFrames
	_expect(idle_top != null and idle_top.get_size() == EXPECTED_FRAME_SIZE, "Ranger rear idle is not 128x128.")
	_expect(idle_bottom != null and idle_bottom.get_size() == EXPECTED_FRAME_SIZE, "Ranger front idle is not 128x128.")
	for animation_name: StringName in [&"move_bottom", &"move_top"]:
		_expect(frames != null and frames.has_animation(animation_name), "Missing Ranger animation %s." % animation_name)
		if frames != null and frames.has_animation(animation_name):
			_expect(frames.get_frame_count(animation_name) == 8, "%s is not eight frames." % animation_name)
			_expect(is_equal_approx(frames.get_animation_speed(animation_name), 10.0), "%s is not 10 FPS." % animation_name)
	_expect((EXPECTED_FRAME_SIZE * DISPLAY_SCALE) == RUNTIME_FOOTPRINT, "Showcase does not match the 96x96 runtime footprint.")
	ranger.free()

	var comparison_scenes: Array[PackedScene] = [HEAVY_ASSAULT_SCENE, MELEE_SCENE, COLLECTOR_SCENE, TURRET_SCENE]
	for scene in comparison_scenes:
		var instance := scene.instantiate()
		var texture := instance.get("mecha_idle_bottom_texture") as Texture2D
		var move_frames := instance.get("mecha_move_sprite_frames") as SpriteFrames
		_expect(texture != null and texture.resource_path == "res://asset/images/characters/pixel/idle_bottom.png", "%s no longer uses the shared idle resource." % instance.name)
		_expect(move_frames != null and move_frames.resource_path == "res://Player/Mechas/animations/mecha_move_frames.tres", "%s no longer uses the shared movement resource." % instance.name)
		instance.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
