extends Control

const PLAYER_STATUS_SCENE := preload("res://UI/components/PlayerStatusHud/PlayerStatusHud.tscn")
const BATTLE_TIME_SCENE := preload("res://UI/components/BattleTimeMeter/BattleTimeMeter.tscn")
const GOLD_SCENE := preload("res://UI/components/GoldHudDisplay/GoldHudDisplay.tscn")
const TOAST_SCENE := preload("res://UI/components/ToastDock/ToastDock.tscn")
const PHASE_DOCK_SCENE := preload("res://UI/components/PhaseDock/PhaseDock.tscn")
const REWARD_CARD_SCENE := preload("res://UI/components/RewardCard/RewardCard.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

const ACCENT := Color("45d6c7")
const ACCENT_HOT := Color("ffb454")
const INK := Color("d8eeef")
const MUTED := Color("78989b")
const PANEL := Color("17282c")
const PANEL_DARK := Color("0b1518")
const SIDEBAR_WIDTH := 220.0

var _pages: Array[Dictionary] = []
var _page_index := 0
var _state_index := 0
var _background_index := 0
var _locale := "zh_CN"
var _show_guides := false
var _focus_mode := false
var _shell: Control
var _sidebar: VBoxContainer
var _content: Control
var _page_title: Label
var _page_meta: Label
var _state_label: Label
var _counter: Label
var _notes: Label
var _catalog_search: LineEdit
var _catalog_rows: VBoxContainer
var _embedded_active := false

func _ready() -> void:
	_build_page_registry()
	_build_shell()
	LocalizationManager.set_locale(_locale, false)
	_show_page(0)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	queue_redraw()
	if "--capture-ui-gallery" in OS.get_cmdline_user_args():
		_capture_review_frame.call_deferred()

func _capture_review_frame() -> void:
	var capture_root := OS.get_temp_dir().path_join("magarena_ui_gallery")
	DirAccess.make_dir_recursive_absolute(capture_root)
	var final_error := OK
	for index in _pages.size():
		_show_page(index)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture_path := capture_root.path_join("page_%02d.png" % [index + 1])
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		if error != OK:
			final_error = error
		print("UI_GALLERY_CAPTURE=", capture_path, " ERROR=", error)
	_show_page(0)
	await get_tree().process_frame
	await get_tree().process_frame
	await TEST_TEARDOWN.finish(self, 0 if final_error == OK else 1)

func _build_page_registry() -> void:
	_pages = [
		{"category": "入口", "title": "展厅索引", "states": ["概览"], "builder": _build_overview,
			"notes": "先按玩家流程浏览，再进入组件目录或专项 Showcase。所有数据均为展示样本。"},
		{"category": "战斗 HUD", "title": "玩家状态", "states": ["常态", "危险", "满能量", "冷却", "空资源"], "builder": _build_player_status,
			"notes": "真实 PlayerStatusHud。检查生命、护盾、能量、技能就绪与低血量语义。"},
		{"category": "战斗 HUD", "title": "阶段与计时", "states": ["准备", "战斗", "警告", "结束"], "builder": _build_phase_and_time,
			"notes": "真实 PhaseDock 与 BattleTimeMeter。观察阶段优先级和紧急计时状态。"},
		{"category": "战斗 HUD", "title": "经济与提示", "states": ["默认", "获得金币", "消费金币", "长文本"], "builder": _build_feedback,
			"notes": "真实 GoldHudDisplay 与 ToastDock。检查数字跳变、长文本和背景对比度。"},
		{"category": "奖励", "title": "奖励卡片", "states": ["默认", "选中", "长文本", "不可用"], "builder": _build_rewards,
			"notes": "真实 RewardCard 容器配展示数据。检查三卡密度、选择层级及双语长度。"},
		{"category": "系统", "title": "模态与输入", "states": ["键鼠", "手柄", "危险确认", "禁用"], "builder": _build_modal_and_input,
			"notes": "检查焦点顺序、主次按钮、危险操作与输入提示是否只依赖颜色。"},
		{"category": "奖励", "title": "奖励草案统一", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/reward_draft_unification_showcase.tscn"),
			"notes": "生产奖励选择面板。页面内使用 L、F、H、R 检查语言、焦点、按住确认和重置。"},
		{"category": "奖励", "title": "奖励卡片图鉴", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/reward_card_gallery_showcase.tscn"),
			"notes": "生产奖励卡片的武器、模块和升级内容组合。"},
		{"category": "奖励", "title": "武器核心卡", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/weapon_core_card_showcase.tscn"),
			"notes": "生产武器核心卡。页面内使用 0–4 检查标签焦点和兼容性。"},
		{"category": "管理", "title": "模块装备选择", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/module_equip_selection_showcase.tscn"),
			"notes": "生产模块装备选择面板及武器适配状态。"},
		{"category": "管理", "title": "触发模块卡片", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/skill_trigger_module_card_showcase.tscn"),
			"notes": "技能触发型模块卡片、条件和操作反馈。"},
		{"category": "合约", "title": "合约选择", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/battle_contract_selection_expanded_showcase.tscn"),
			"notes": "生产协议选择器的双卡、三卡密度与增强合约状态。"},
		{"category": "合约", "title": "合约难度比较", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/contract_difficulty_comparison_showcase.tscn"),
			"notes": "标准合约和增强风险合约的并列比较。"},
		{"category": "合约", "title": "协议图像", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/protocol_image_showcase.tscn"),
			"notes": "协议插画、标题、规则和双语排版。页面内使用方向键与 L。"},
		{"category": "战斗 HUD", "title": "金币补给 HUD", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/gold_supply_hud_showcase.tscn"),
			"notes": "完整运行时 UI 中的金币补给状态。页面内使用 1–6、L、G。"},
		{"category": "战斗 HUD", "title": "被动动作徽章", "states": ["交互式"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/passive_action_badge_showcase.tscn"),
			"notes": "武器被动动作、可用、触发和冷却状态。"},
		{"category": "战斗 HUD", "title": "热量可访问性", "states": ["静态"], "builder": _build_embedded_showcase.bind("res://tests/showcases/ui/heat_accessibility_showcase.tscn"),
			"notes": "热量状态在不依赖颜色时的可读性检查。"},
		{"category": "目录", "title": "生产 UI 场景目录", "states": ["全部"], "builder": _build_catalog,
			"notes": "自动扫描 UI 下的生产 .tscn。可搜索路径，用于发现尚未加入专页的组件。"},
	]

func _build_shell() -> void:
	_shell = Control.new()
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shell)

	var sidebar_panel := PanelContainer.new()
	sidebar_panel.position = Vector2(16, 16)
	sidebar_panel.size = Vector2(SIDEBAR_WIDTH, size.y - 32)
	sidebar_panel.add_theme_stylebox_override("panel", _style(PANEL_DARK, ACCENT.darkened(0.45), 1, 8))
	_shell.add_child(sidebar_panel)
	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 2)
	sidebar_panel.add_child(_sidebar)
	var brand := _label("MAGARENA\nUI GALLERY", 23, ACCENT)
	brand.custom_minimum_size.y = 68
	_sidebar.add_child(brand)
	var sub := _label("MANUAL REVIEW SURFACE", 10, MUTED)
	_sidebar.add_child(sub)
	_sidebar.add_child(HSeparator.new())
	for index in _pages.size():
		var page: Dictionary = _pages[index]
		var button := Button.new()
		button.text = "%02d  %s" % [index + 1, page.title]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 24
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = "%s / %s" % [page.category, page.notes]
		button.pressed.connect(_show_page.bind(index))
		_sidebar.add_child(button)
	var help := _label("Q/E 翻页   A/D 状态\nL 语言   B 背景   G 参考线\nF 专注模式   R 重置", 12, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sidebar.add_child(help)

	var main := VBoxContainer.new()
	main.position = Vector2(SIDEBAR_WIDTH + 32, 16)
	main.size = Vector2(size.x - SIDEBAR_WIDTH - 48, size.y - 32)
	main.add_theme_constant_override("separation", 8)
	_shell.add_child(main)

	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 58
	main.add_child(top)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	_page_title = _label("", 24, INK)
	heading.add_child(_page_title)
	_page_meta = _label("", 11, MUTED)
	heading.add_child(_page_meta)
	_counter = _label("", 13, ACCENT)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_counter)

	var stage_panel := PanelContainer.new()
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.075, 0.94), Color("31575d"), 1, 8))
	main.add_child(stage_panel)
	_content = Control.new()
	_content.clip_contents = true
	stage_panel.add_child(_content)

	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size.y = 66
	bottom.add_theme_constant_override("separation", 8)
	main.add_child(bottom)
	bottom.add_child(_nav_button("◀ 上一页", _previous_page))
	bottom.add_child(_nav_button("状态 ◀", _previous_state))
	_state_label = _label("", 13, ACCENT_HOT)
	_state_label.custom_minimum_size.x = 110
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_state_label)
	bottom.add_child(_nav_button("状态 ▶", _next_state))
	bottom.add_child(_nav_button("下一页 ▶", _next_page))
	_notes = _label("", 11, MUTED)
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_notes)
	bottom.add_child(_nav_button("中文 / EN", _toggle_locale))
	bottom.add_child(_nav_button("背景", _cycle_background))
	bottom.add_child(_nav_button("参考线", _toggle_guides))

func _show_page(index: int) -> void:
	_page_index = wrapi(index, 0, _pages.size())
	_state_index = 0
	_render_current_page()

func _render_current_page() -> void:
	_embedded_active = false
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_catalog_search = null
	_catalog_rows = null
	var page: Dictionary = _pages[_page_index]
	_page_title.text = page.title
	_page_meta.text = "%s  ·  1280×720 基准  ·  %s" % [page.category, "中文" if _locale == "zh_CN" else "English"]
	_counter.text = "%02d / %02d" % [_page_index + 1, _pages.size()]
	var states: Array = page.states
	_state_index = wrapi(_state_index, 0, states.size())
	_state_label.text = states[_state_index]
	_notes.text = page.notes
	page.builder.call()
	queue_redraw()

func _build_overview() -> void:
	var root := _page_margin()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)
	column.add_child(_label("一个入口，观察整套界面语言", 28, INK))
	column.add_child(_label("生产组件状态实验室 + 完整场景目录 + 专项 Showcase 导航", 15, ACCENT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	var cards := [
		["战斗 HUD", "生命 / 护盾 / 能量\n阶段 / 计时 / 经济 / 提示"],
		["奖励与选择", "卡片密度 / 选中 / 长文本\n兼容性与不可用状态"],
		["系统交互", "模态 / 输入方式 / 焦点\n危险操作与禁用状态"],
		["响应式观察", "安全区 / 背景对比度\n中英文与极端内容"],
		["生产目录", "自动列出 UI 场景\n帮助发现未覆盖组件"],
		["专项实验室", "进入现有高保真展示\n复用已建立的视觉样本"],
	]
	for data in cards:
		grid.add_child(_info_card(data[0], data[1]))
	column.add_child(_label("建议浏览顺序：战斗 HUD → 奖励 → 系统 → 生产目录 → 专项 Showcase", 13, MUTED))

func _build_player_status() -> void:
	var root := _page_margin()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	root.add_child(stack)
	stack.add_child(_section_heading("真实玩家状态 HUD", "切换状态检查边界值与语义"))
	var status = PLAYER_STATUS_SCENE.instantiate()
	status.custom_minimum_size = Vector2(540, 150)
	stack.add_child(status)
	match _state_index:
		0:
			status.set_health(82, 100, 35, 50); status.set_energy(62, 100); status.set_skill_cost(50); status.set_skill_available(true)
		1:
			status.set_health(9, 100, 0, 50); status.set_energy(12, 100); status.set_skill_cost(50); status.set_skill_available(false)
		2:
			status.set_health(100, 100, 50, 50); status.set_energy(100, 100); status.set_skill_cost(50); status.set_skill_available(true)
		3:
			status.set_health(64, 100, 10, 50); status.set_energy(100, 100); status.set_skill_cost(50); status.set_cooldown(4.7, 8.0)
		4:
			status.set_health(1, 100, 0, 50); status.set_energy(0, 100); status.set_skill_cost(50); status.set_skill_available(false)
	stack.add_child(_state_checklist(["生命与护盾轨道仍然可分辨", "技能状态不只依赖颜色", "0%、1% 与 100% 均不压住边框", "危险状态不会遮挡数值"]))

func _build_phase_and_time() -> void:
	var root := _page_margin()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_section_heading("阶段导航", "真实 PhaseDock"))
	var dock = PHASE_DOCK_SCENE.instantiate()
	dock.custom_minimum_size = Vector2(420, 120)
	left.add_child(dock)
	var phase_names := ["准备部署", "战斗进行中", "撤离警告", "区域已肃清"]
	dock.set_phase_text(phase_names[_state_index])
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(_section_heading("战斗计时", "真实 BattleTimeMeter"))
	var meter = BATTLE_TIME_SCENE.instantiate()
	var meter_center := CenterContainer.new()
	meter_center.custom_minimum_size = Vector2(260, 180)
	right.add_child(meter_center)
	meter_center.add_child(meter)
	var times := [60, 38, 8, 0]
	meter.set_time(times[_state_index], 60, "battle")

func _build_feedback() -> void:
	var root := _page_margin()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	root.add_child(stack)
	stack.add_child(_section_heading("经济与即时反馈", "真实数字显示与 Toast 动画"))
	var gold = GOLD_SCENE.instantiate()
	gold.custom_minimum_size = Vector2(300, 70)
	stack.add_child(gold)
	var values := [1280, 1620, 75, 999999]
	gold.set_gold_value(values[_state_index], _state_index > 0)
	var toast = TOAST_SCENE.instantiate()
	toast.custom_minimum_size = Vector2(680, 90)
	stack.add_child(toast)
	var messages := ["模块已装备", "+340 金币 · 补给进度提升", "金币不足 · 无法完成购买", "超长提示：该武器核心与当前主武器槽位不兼容，请先选择另一件武器或整理仓库后重试。"]
	toast.set_message(messages[_state_index])
	toast.visible = true
	toast.modulate.a = 1.0
	stack.add_child(_state_checklist(["增长与减少使用不同语义", "提示在复杂背景上仍可读", "长文本不会越过安全区", "动画停止时信息仍然完整"]))

func _build_rewards() -> void:
	var root := _page_margin()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	root.add_child(stack)
	stack.add_child(_section_heading("奖励选择", "真实 RewardCard 容器 · 三卡密度"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	var titles := ["脉冲核心", "寒霜协议", "超载弹仓"]
	var bodies := ["提升射速并保留稳定性", "冻结范围内的普通敌人", "弹药耗尽时获得短暂强化"]
	for index in 3:
		var card = REWARD_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(250, 300)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var long_suffix := "；该说明用于检查中文长行在窄卡片中的换行、层级和底部安全间距" if _state_index == 2 else ""
		card.set_data({"reward_index": index, "key_text": str(index + 1), "type_label": "推荐" if index == 1 else "武器", "selected_text": "已选择", "accent_color": ACCENT_HOT if index == 1 else ACCENT, "minimum_height": 300.0})
		var card_body: VBoxContainer = card.get_content_root()
		var hero := _label(titles[index], 21, INK)
		hero.custom_minimum_size.y = 72
		hero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_body.add_child(hero)
		var rule := HSeparator.new()
		card_body.add_child(rule)
		var description := _label(bodies[index] + long_suffix, 13, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_body.add_child(description)
		var action := _label("按住确认" if index == 1 else "查看详情", 12, ACCENT_HOT if index == 1 else ACCENT)
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_body.add_child(action)
		card.set_selected(_state_index == 1 and index == 1)
		card.modulate = Color(0.55, 0.6, 0.62) if _state_index == 3 and index == 2 else Color.WHITE

func _build_modal_and_input() -> void:
	var root := _page_margin()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	root.add_child(column)
	column.add_child(_section_heading("模态层与输入提示", "键盘、手柄、危险操作及不可用状态"))
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.025, 0.72)
	dim.custom_minimum_size = Vector2(760, 320)
	column.add_child(dim)
	var dialog := VBoxContainer.new()
	dialog.position = Vector2(120, 44)
	dialog.size = Vector2(520, 230)
	dialog.add_theme_constant_override("separation", 14)
	dim.add_child(dialog)
	var title := "确认拆解？" if _state_index == 2 else "装备模块"
	dialog.add_child(_label(title, 24, Color("ff8374") if _state_index == 2 else INK))
	var copy := "此操作无法撤销。模块将转化为 120 金币。" if _state_index == 2 else "将“动能增幅器”安装到主武器槽位。"
	dialog.add_child(_label(copy, 15, INK))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	dialog.add_child(buttons)
	var confirm := Button.new(); confirm.text = "确认 [Enter]"; confirm.disabled = _state_index == 3
	var cancel := Button.new(); cancel.text = "取消 [Esc]"
	buttons.add_child(confirm); buttons.add_child(cancel)
	var device := "手柄：A 确认 / B 返回" if _state_index == 1 else "键鼠：Enter 确认 / Esc 返回 / Tab 切换焦点"
	dialog.add_child(_label(device, 12, ACCENT))
	confirm.grab_focus.call_deferred()

func _build_embedded_showcase(scene_path: String) -> void:
	_embedded_active = true
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	_content.add_child(aspect)
	var viewport_container := SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	aspect.add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	viewport_container.add_child(viewport)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		var failure := _label("无法加载内部展示页：\n" + scene_path, 18, Color("ff8374"))
		failure.position = Vector2(32, 32)
		viewport.add_child(failure)
		return
	var page_root := packed.instantiate()
	if page_root is Control:
		(page_root as Control).set_anchors_preset(Control.PRESET_TOP_LEFT)
		(page_root as Control).position = Vector2.ZERO
		(page_root as Control).size = Vector2(1280, 720)
	viewport.add_child(page_root)
	viewport.size_changed.connect(_apply_embedded_fit.bind(page_root, viewport))
	_apply_embedded_fit.call_deferred(page_root, viewport)

func _apply_embedded_fit(page_root: Node, viewport: SubViewport) -> void:
	if not is_instance_valid(page_root) or not is_instance_valid(viewport):
		return
	var available := Vector2(viewport.size)
	var factor := minf(available.x / 1280.0, available.y / 720.0)
	if page_root is CanvasItem:
		(page_root as CanvasItem).scale = Vector2.ONE * factor
	if page_root is Control:
		(page_root as Control).position = (available - Vector2(1280, 720) * factor) * 0.5

func _build_catalog() -> void:
	var root := _page_margin()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)
	column.add_child(_section_heading("生产 UI 场景目录", "自动扫描 res://UI · 新组件无需手工登记"))
	_catalog_search = LineEdit.new()
	_catalog_search.placeholder_text = "搜索名称或路径…"
	_catalog_search.text_changed.connect(_refresh_catalog)
	column.add_child(_catalog_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_catalog_rows = VBoxContainer.new()
	_catalog_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_catalog_rows)
	_refresh_catalog("")
	_catalog_search.grab_focus.call_deferred()

func _refresh_catalog(filter: String) -> void:
	if not is_instance_valid(_catalog_rows):
		return
	for child in _catalog_rows.get_children():
		child.queue_free()
	var paths: Array[String] = []
	_collect_scenes("res://UI", paths)
	paths.sort()
	var needle := filter.to_lower()
	var shown := 0
	for path in paths:
		if not needle.is_empty() and not needle in path.to_lower():
			continue
		var row := HBoxContainer.new()
		var name_label := _label(path.get_file().get_basename(), 13, INK)
		name_label.custom_minimum_size.x = 240
		row.add_child(name_label)
		var path_label := _label(path.trim_prefix("res://"), 11, MUTED)
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(path_label)
		_catalog_rows.add_child(row)
		shown += 1
	var summary := _label("显示 %d / %d 个场景" % [shown, paths.size()], 11, ACCENT)
	_catalog_rows.add_child(summary)

func _collect_scenes(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scenes(path, output)
		elif entry.ends_with(".tscn"):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _page_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	_content.add_child(margin)
	return margin

func _section_heading(title: String, subtitle: String) -> Control:
	var column := VBoxContainer.new()
	column.add_child(_label(title, 21, INK))
	column.add_child(_label(subtitle, 11, MUTED))
	return column

func _state_checklist(items: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("102024"), Color("29464b"), 1, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	for item in items:
		var label := _label("◆ " + str(item), 11, MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
	return panel

func _info_card(title: String, body: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(245, 125)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("31565b"), 1, 6))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_label(title, 17, ACCENT))
	var copy := _label(body, 12, INK)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(copy)
	return panel

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _nav_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.pressed.connect(callback)
	return button

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _previous_page() -> void: _show_page(_page_index - 1)
func _next_page() -> void: _show_page(_page_index + 1)
func _previous_state() -> void:
	_state_index -= 1
	_render_current_page()
func _next_state() -> void:
	_state_index += 1
	_render_current_page()
func _toggle_locale() -> void:
	_locale = "en" if _locale == "zh_CN" else "zh_CN"
	LocalizationManager.set_locale(_locale, false)
	_render_current_page()
func _cycle_background() -> void:
	_background_index = wrapi(_background_index + 1, 0, 4)
	queue_redraw()
func _toggle_guides() -> void:
	_show_guides = not _show_guides
	queue_redraw()

func _toggle_focus_mode() -> void:
	_focus_mode = not _focus_mode
	_sidebar.get_parent().visible = not _focus_mode
	var main := _content.get_parent().get_parent() as Control
	main.position = Vector2(16, 16) if _focus_mode else Vector2(SIDEBAR_WIDTH + 32, 16)
	main.size = Vector2(size.x - 32, size.y - 32) if _focus_mode else Vector2(size.x - SIDEBAR_WIDTH - 48, size.y - 32)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _embedded_active:
		if event.keycode == KEY_Q:
			_previous_page()
		elif event.keycode == KEY_E:
			_next_page()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_Q: _previous_page()
		KEY_E: _next_page()
		KEY_A: _previous_state()
		KEY_D: _next_state()
		KEY_L: _toggle_locale()
		KEY_B: _cycle_background()
		KEY_G: _toggle_guides()
		KEY_F: _toggle_focus_mode()
		KEY_R:
			_state_index = 0; _background_index = 0; _render_current_page()
		_: return
	get_viewport().set_input_as_handled()

func _on_viewport_size_changed() -> void:
	if not is_instance_valid(_shell):
		return
	_shell.size = size
	var sidebar_panel := _sidebar.get_parent() as Control
	sidebar_panel.size.y = size.y - 32
	var main := _content.get_parent().get_parent() as Control
	main.size = Vector2(size.x - 32, size.y - 32) if _focus_mode else Vector2(size.x - SIDEBAR_WIDTH - 48, size.y - 32)
	queue_redraw()

func _draw() -> void:
	var colors := [Color("101c20"), Color("dedbd1"), Color("371d24"), Color("142d26")]
	draw_rect(Rect2(Vector2.ZERO, size), colors[_background_index])
	var line_color := Color(0.22, 0.43, 0.45, 0.22) if _background_index != 1 else Color(0.12, 0.2, 0.22, 0.15)
	for x in range(0, int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), line_color)
	for y in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), line_color)
	if _show_guides:
		var safe := Rect2(Vector2(32, 32), size - Vector2(64, 64))
		draw_rect(safe, Color("ffb454"), false, 2)
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), Color(0.27, 0.84, 0.78, 0.55), 1)
		draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(0.27, 0.84, 0.78, 0.55), 1)
