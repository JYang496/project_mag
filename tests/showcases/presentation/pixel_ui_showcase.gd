extends Control

const PIXEL_THEME := preload("res://UI/themes/global_ui_theme.tres")
const PLAYER_STATUS_HUD_SCRIPT := preload("res://UI/scripts/components/player_status_hud.gd")
const MODULE_ICONS := [
	preload("res://asset/images/modules/pixel/wmod_damage_up_stat.png"),
	preload("res://asset/images/modules/pixel/wmod_pierce_stat.png"),
	preload("res://asset/images/modules/pixel/wmod_projectile_speed_stat.png"),
	preload("res://asset/images/modules/pixel/wmod_bullet_size_stat.png"),
	preload("res://asset/images/modules/pixel/wmod_fast_reload.png"),
	preload("res://asset/images/modules/pixel/wmod_expanded_magazine.png"),
	preload("res://asset/images/modules/pixel/wmod_lifesteal_on_hit.png"),
	preload("res://asset/images/modules/pixel/wmod_reload_speed_link.png"),
]


func _ready() -> void:
	print("PIXEL_UI_VIEWPORT=%s CONTROL_SIZE=%s" % [get_viewport().get_visible_rect().size, size])
	theme = PIXEL_THEME
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_background()
	_build_title()
	_build_menu()
	_build_hud()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var output_path := OS.get_environment("PIXEL_UI_QA_PATH")
	if not output_path.is_empty():
		var error := get_viewport().get_texture().get_image().save_png(output_path)
		if error != OK:
			push_error("Pixel UI showcase screenshot failed: %s" % error_string(error))
	get_tree().quit()


func _build_background() -> void:
	var viewport_size := get_viewport_rect().size
	var background := ColorRect.new()
	background.color = Color(0.012, 0.02, 0.03, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)
	for y in range(0, ceili(viewport_size.y), 16):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(viewport_size.x, 1)
		line.color = Color(0.04, 0.12, 0.15, 0.42)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(line)


func _build_title() -> void:
	var viewport_size := get_viewport_rect().size
	var title := Label.new()
	title.position = Vector2(32, 24)
	title.size = Vector2(viewport_size.x - 64.0, 54)
	title.text = "PROTOCOL // 像素作战终端"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.94))
	add_child(title)


func _build_menu() -> void:
	var viewport_size := get_viewport_rect().size
	var panel := PanelContainer.new()
	panel.position = Vector2((viewport_size.x - 500.0) * 0.5, 96)
	panel.size = Vector2(500, 454)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "战斗系统 / BATTLE SYSTEM"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34))
	column.add_child(heading)
	var separator := HSeparator.new()
	column.add_child(separator)
	for text in ["继续作战", "模块管理", "返回主菜单"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(0, 42)
		column.add_child(button)
	var option := OptionButton.new()
	option.add_item("1280 × 720  [2X PIXEL]")
	option.add_item("1920 × 1080")
	option.custom_minimum_size = Vector2(0, 38)
	column.add_child(option)
	var toggle := CheckButton.new()
	toggle.text = "自动换弹 / AUTO RELOAD"
	toggle.button_pressed = true
	column.add_child(toggle)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 20)
	progress.value = 68
	progress.show_percentage = false
	column.add_child(progress)
	var icon_label := Label.new()
	icon_label.text = "常用模块 // COMMON MODULES"
	icon_label.add_theme_font_size_override("font_size", 13)
	column.add_child(icon_label)
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 8)
	column.add_child(icon_row)
	for texture in MODULE_ICONS:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_row.add_child(icon)


func _build_hud() -> void:
	var viewport_size := get_viewport_rect().size
	var safe_left := maxf((viewport_size.x - 1280.0) * 0.5, 0.0)
	var frame := TextureRect.new()
	frame.position = Vector2(safe_left + 28.0, viewport_size.y - 132.0)
	frame.size = Vector2(356, 96)
	frame.texture = preload("res://UI/themes/player_status_hud/generated/ui_frame_clean_panel.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(frame)
	var status := PLAYER_STATUS_HUD_SCRIPT.new() as Control
	status.position = Vector2(14, 14)
	frame.add_child(status)
	status.call_deferred("set_health", 78, 120, 24, 40)
	status.call_deferred("set_energy", 91, 125)
	status.call_deferred("set_skill_cost", 25)
	status.call_deferred("set_ammo", 18, 30, true)
	var caption := Label.new()
	caption.position = Vector2(safe_left + 410.0, viewport_size.y - 108.0)
	caption.size = Vector2(330, 52)
	caption.text = "HUD // HP 078  SHIELD 024\nENERGY 091  AMMO 18/30"
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.55, 0.84, 0.88))
	add_child(caption)
