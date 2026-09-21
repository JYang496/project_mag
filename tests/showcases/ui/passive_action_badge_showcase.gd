extends Control
## Manual gallery for the production passive-action badge component.

const BADGE_SCENE := preload("res://UI/components/WeaponEffectBadge/WeaponEffectBadge.tscn")
const READY_COLOR := Color("f4bc53")
const WAITING_COLOR := Color("83a9b8")
const BACKGROUND := Color("17152e")

var _badges: Array[Control] = []
var _state_labels: Array[Label] = []
var _states := [0, 0, 0, 0, 0]
var _auto_play := true
var _elapsed := 0.0


func _ready() -> void:
	_build_showcase()
	_refresh_all()
	if "--capture-passive-action-badges" in OS.get_cmdline_user_args():
		call_deferred("_capture_showcase")


func _process(delta: float) -> void:
	if not _auto_play:
		return
	_elapsed += delta
	if _elapsed < 1.0:
		return
	_elapsed = 0.0
	for index in range(_states.size()):
		_advance(index)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		_advance(int(key - KEY_1))
	elif key == KEY_SPACE:
		_auto_play = not _auto_play
		_refresh_all()


func _build_showcase() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var page := VBoxContainer.new()
	page.position = Vector2(72, 42)
	page.size = Vector2(1136, 636)
	page.add_theme_constant_override("separation", 14)
	add_child(page)

	var title := Label.new()
	title.text = "被动徽章 · 操作触发语义"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("d9f7ff"))
	page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "灰蓝 = 等待/前置操作    黄色 = 已就绪；按 1–5 单独推进，空格暂停自动演示"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("9bb9c5"))
	page.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	page.add_child(grid)

	var entries := [
		{"title": "1  下一次开火", "detail": "迫击炮 / 狙击 / 冰川\n计时结束后，下一次开火触发"},
		{"title": "2  下一次换弹", "detail": "机枪\n换弹消耗当前层数并发动增益"},
		{"title": "3  切入主手", "detail": "霰弹枪\n先切入主手，再由下一次开火触发"},
		{"title": "4  倒计时", "detail": "支援位蓄力\n数字是距离就绪的整秒数"},
		{"title": "5  释放技能", "detail": "预留统一语义\n供未来技能触发型被动复用"},
	]
	for index in range(entries.size()):
		grid.add_child(_build_card(index, entries[index]))

	var footer := Label.new()
	footer.text = "每张卡同时显示 2× 检视尺寸与右下角 1× 实际 HUD 尺寸。徽章图形直接复用生产组件。"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color("7895a3"))
	page.add_child(footer)


func _build_card(index: int, entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(216, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("20243b")
	style.border_color = Color("3a6680")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = str(entry["title"])
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", READY_COLOR)
	column.add_child(heading)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(184, 142)
	column.add_child(stage)
	var badge := BADGE_SCENE.instantiate() as Control
	badge.position = Vector2(62, 34)
	badge.size = Vector2(30, 20)
	badge.scale = Vector2(2, 2)
	stage.add_child(badge)
	_badges.append(badge)

	var actual_badge := BADGE_SCENE.instantiate() as Control
	actual_badge.name = "ActualHudSizeBadge"
	actual_badge.position = Vector2(146, 108)
	actual_badge.size = Vector2(30, 20)
	stage.add_child(actual_badge)
	badge.set_meta(&"actual_badge", actual_badge)

	var actual_label := Label.new()
	actual_label.text = "1×"
	actual_label.position = Vector2(116, 105)
	actual_label.add_theme_font_size_override("font_size", 11)
	actual_label.add_theme_color_override("font_color", Color("7895a3"))
	stage.add_child(actual_label)

	var state_label := Label.new()
	state_label.custom_minimum_size = Vector2(184, 48)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 16)
	state_label.add_theme_color_override("font_color", Color("d9f7ff"))
	column.add_child(state_label)
	_state_labels.append(state_label)

	var detail := Label.new()
	detail.text = str(entry["detail"])
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(184, 78)
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", Color("9bb9c5"))
	column.add_child(detail)

	var button := Button.new()
	button.text = "推进状态 [%d]" % (index + 1)
	button.pressed.connect(_advance.bind(index))
	column.add_child(button)
	return panel


func _advance(index: int) -> void:
	if index < 0 or index >= _states.size():
		return
	_states[index] += 1
	_refresh(index)


func _refresh_all() -> void:
	for index in range(_states.size()):
		_refresh(index)


func _refresh(index: int) -> void:
	var symbol := "fire"
	var amount := 0
	var color := READY_COLOR
	var text := "已就绪：下一次开火"
	match index:
		0:
			var remaining: int = 5 - (int(_states[index]) % 6)
			if remaining > 0:
				symbol = "timer"
				amount = remaining
				color = WAITING_COLOR
				text = "等待 %d 秒" % remaining
		1:
			amount = 1 + (_states[index] % 4)
			symbol = "reload"
			text = "换弹时消耗 %d 层" % amount
		2:
			if _states[index] % 2 == 0:
				symbol = "swap"
				color = WAITING_COLOR
				text = "先切入主手"
			else:
				symbol = "fire"
				text = "已就绪：下一次开火"
		3:
			var remaining: int = 5 - (int(_states[index]) % 5)
			symbol = "timer"
			amount = remaining
			color = WAITING_COLOR
			text = "还需 %d 秒" % remaining
		4:
			symbol = "skill"
			text = "已就绪：释放技能"
	_configure_pair(_badges[index], symbol, amount, color)
	_state_labels[index].text = text


func _configure_pair(badge: Control, symbol: String, amount: int, color: Color) -> void:
	badge.call("configure", symbol, amount, color)
	var actual_badge := badge.get_meta(&"actual_badge", null) as Control
	if actual_badge != null:
		actual_badge.call("configure", symbol, amount, color)


func _capture_showcase() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://output/showcases/ui")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("passive_action_badge_showcase.png")
	var error := image.save_png(path)
	print("PASS: passive action badge showcase captured at %s" % path if error == OK else "FAIL: showcase capture error %d" % error)
	get_tree().quit(0 if error == OK else 1)
