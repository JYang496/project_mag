extends Control

const THEME_ORDER: PackedStringArray = [
	"teal_hangar",
	"amber_foundry",
	"crimson_dock",
	"ice_lab",
	"military_olive",
	"neon_arcade",
	"clean_monochrome",
	"toxic_swamp",
	"desert_relay",
	"obsidian_gold",
]

const THEMES := {
	"teal_hangar": {
		"bg": Color("0b1220"),
		"panel": Color("132033"),
		"panel_alt": Color("0f1a2a"),
		"panel_soft": Color("111c2f"),
		"panel_deep": Color("0b1523"),
		"border": Color("27445f"),
		"accent": Color("2ee6c9"),
		"accent_alt": Color("f8c35d"),
		"text_muted": Color("9cb3c9"),
		"text_body": Color("d7e6f7"),
		"success": Color("8ef0a6"),
		"warning": Color("ff9577"),
		"button_fill": Color("2ee6c9"),
		"button_text": Color("0a1422"),
		"button_disabled": Color("33455b"),
		"socket_ready_fill": Color("113b37"),
		"socket_full_fill": Color("2a2236"),
		"socket_blocked_fill": Color("381b22"),
	},
	"amber_foundry": {
		"bg": Color("19120c"),
		"panel": Color("2d1d13"),
		"panel_alt": Color("24160d"),
		"panel_soft": Color("312015"),
		"panel_deep": Color("1c120b"),
		"border": Color("6d4a2d"),
		"accent": Color("ffb347"),
		"accent_alt": Color("ffe08a"),
		"text_muted": Color("d3bc9e"),
		"text_body": Color("fff0d6"),
		"success": Color("b4f06c"),
		"warning": Color("ff8f5b"),
		"button_fill": Color("ffb347"),
		"button_text": Color("25170d"),
		"button_disabled": Color("5a4736"),
		"socket_ready_fill": Color("4a3412"),
		"socket_full_fill": Color("4b2430"),
		"socket_blocked_fill": Color("48231d"),
	},
	"crimson_dock": {
		"bg": Color("160c12"),
		"panel": Color("28131d"),
		"panel_alt": Color("1f1018"),
		"panel_soft": Color("311723"),
		"panel_deep": Color("180b12"),
		"border": Color("60354c"),
		"accent": Color("ff5c8a"),
		"accent_alt": Color("ffd166"),
		"text_muted": Color("d4a9b9"),
		"text_body": Color("ffe4ec"),
		"success": Color("8be28f"),
		"warning": Color("ff8d6a"),
		"button_fill": Color("ff5c8a"),
		"button_text": Color("240d15"),
		"button_disabled": Color("553949"),
		"socket_ready_fill": Color("253c2c"),
		"socket_full_fill": Color("3f1f2d"),
		"socket_blocked_fill": Color("402024"),
	},
	"ice_lab": {
		"bg": Color("09141b"),
		"panel": Color("102833"),
		"panel_alt": Color("0d2028"),
		"panel_soft": Color("12303c"),
		"panel_deep": Color("0b1b23"),
		"border": Color("2f6171"),
		"accent": Color("62d6ff"),
		"accent_alt": Color("c8f36a"),
		"text_muted": Color("9fc3cf"),
		"text_body": Color("ddf6ff"),
		"success": Color("9ef07f"),
		"warning": Color("ffad6f"),
		"button_fill": Color("62d6ff"),
		"button_text": Color("0b1820"),
		"button_disabled": Color("35505a"),
		"socket_ready_fill": Color("133d47"),
		"socket_full_fill": Color("25314a"),
		"socket_blocked_fill": Color("3f281f"),
	},
	"military_olive": {
		"bg": Color("12150d"),
		"panel": Color("202616"),
		"panel_alt": Color("1a1f12"),
		"panel_soft": Color("2a311d"),
		"panel_deep": Color("13180e"),
		"border": Color("586043"),
		"accent": Color("a8c95f"),
		"accent_alt": Color("f4d35e"),
		"text_muted": Color("b6bea1"),
		"text_body": Color("e7edd6"),
		"success": Color("a9f07a"),
		"warning": Color("f28c52"),
		"button_fill": Color("a8c95f"),
		"button_text": Color("171b10"),
		"button_disabled": Color("48503d"),
		"socket_ready_fill": Color("354122"),
		"socket_full_fill": Color("34312a"),
		"socket_blocked_fill": Color("3d251b"),
	},
	"neon_arcade": {
		"bg": Color("0c0714"),
		"panel": Color("19102a"),
		"panel_alt": Color("130c21"),
		"panel_soft": Color("24153a"),
		"panel_deep": Color("0f0918"),
		"border": Color("5f3f82"),
		"accent": Color("00f5d4"),
		"accent_alt": Color("ff4fa3"),
		"text_muted": Color("b8a7db"),
		"text_body": Color("f4edff"),
		"success": Color("7cff77"),
		"warning": Color("ff9e4f"),
		"button_fill": Color("00f5d4"),
		"button_text": Color("0b1520"),
		"button_disabled": Color("44365d"),
		"socket_ready_fill": Color("0d4741"),
		"socket_full_fill": Color("3a1d46"),
		"socket_blocked_fill": Color("4a2718"),
	},
	"clean_monochrome": {
		"bg": Color("111111"),
		"panel": Color("202020"),
		"panel_alt": Color("181818"),
		"panel_soft": Color("292929"),
		"panel_deep": Color("141414"),
		"border": Color("575757"),
		"accent": Color("f2f2f2"),
		"accent_alt": Color("bdbdbd"),
		"text_muted": Color("9d9d9d"),
		"text_body": Color("f6f6f6"),
		"success": Color("d9d9d9"),
		"warning": Color("8f8f8f"),
		"button_fill": Color("f2f2f2"),
		"button_text": Color("111111"),
		"button_disabled": Color("474747"),
		"socket_ready_fill": Color("353535"),
		"socket_full_fill": Color("2b2b2b"),
		"socket_blocked_fill": Color("242424"),
	},
	"toxic_swamp": {
		"bg": Color("0d1208"),
		"panel": Color("182211"),
		"panel_alt": Color("12190c"),
		"panel_soft": Color("213017"),
		"panel_deep": Color("0d1308"),
		"border": Color("4b6132"),
		"accent": Color("9cff2e"),
		"accent_alt": Color("e7ff61"),
		"text_muted": Color("aabf8a"),
		"text_body": Color("efffd1"),
		"success": Color("b8ff69"),
		"warning": Color("ff7a3d"),
		"button_fill": Color("9cff2e"),
		"button_text": Color("121907"),
		"button_disabled": Color("425036"),
		"socket_ready_fill": Color("2d4711"),
		"socket_full_fill": Color("353422"),
		"socket_blocked_fill": Color("402317"),
	},
	"desert_relay": {
		"bg": Color("1b140d"),
		"panel": Color("302116"),
		"panel_alt": Color("261a11"),
		"panel_soft": Color("3a281a"),
		"panel_deep": Color("1d140d"),
		"border": Color("7d5c3f"),
		"accent": Color("ffb86b"),
		"accent_alt": Color("ffe29a"),
		"text_muted": Color("d1b494"),
		"text_body": Color("fff1dc"),
		"success": Color("c8f27a"),
		"warning": Color("ff8c5a"),
		"button_fill": Color("ffb86b"),
		"button_text": Color("22170e"),
		"button_disabled": Color("5d4a39"),
		"socket_ready_fill": Color("57401a"),
		"socket_full_fill": Color("4a2b22"),
		"socket_blocked_fill": Color("48261e"),
	},
	"obsidian_gold": {
		"bg": Color("090909"),
		"panel": Color("151515"),
		"panel_alt": Color("101010"),
		"panel_soft": Color("1d1d1d"),
		"panel_deep": Color("0c0c0c"),
		"border": Color("5f5332"),
		"accent": Color("d4af37"),
		"accent_alt": Color("fff0a8"),
		"text_muted": Color("b8ae8a"),
		"text_body": Color("f9f1d0"),
		"success": Color("e3d36b"),
		"warning": Color("c47b3f"),
		"button_fill": Color("d4af37"),
		"button_text": Color("14110a"),
		"button_disabled": Color("464033"),
		"socket_ready_fill": Color("3d3417"),
		"socket_full_fill": Color("2f2619"),
		"socket_blocked_fill": Color("382218"),
	},
}

const SAMPLE_MODULE_SCENES: Array[PackedScene] = [
	preload("res://Player/Weapons/Modules/pierce.tscn"),
	preload("res://Player/Weapons/Modules/life_steal.tscn"),
	preload("res://Player/Weapons/Modules/bullet_size_up.tscn"),
	preload("res://Player/Weapons/Modules/erosion.tscn"),
	preload("res://Player/Weapons/Modules/slow_on_hit.tscn"),
]

const SAMPLE_WEAPON_SCENES: Array[PackedScene] = [
	preload("res://Player/Weapons/pistol.tscn"),
	preload("res://Player/Weapons/hammer.tscn"),
	preload("res://Player/Weapons/rocket_launcher.tscn"),
]

const PRE_EQUIPPED_MODULE_SCENES: Array[PackedScene] = [
	preload("res://Player/Weapons/Modules/damage_up.tscn"),
	preload("res://Player/Weapons/Modules/stun_on_hit.tscn"),
	preload("res://Player/Weapons/Modules/faster_reload.tscn"),
]

const TRACKED_STAT_KEYS: PackedStringArray = [
	"damage",
	"attack_cooldown",
	"projectile_hits",
	"speed",
	"size",
	"hp",
	"dash_speed",
	"return_speed",
	"attack_range",
]

var _sample_inventory_modules: Array[Module] = []
var _sample_weapons: Array[Weapon] = []
var _selected_module: Module
var _preview_weapon: Weapon
var _theme_key: String = "teal_hangar"

var _preview_root: Node
var _background: ColorRect
var _root_panel: PanelContainer
var _header_subtitle: Label
var _theme_selector: OptionButton
var _library_grid: GridContainer
var _detail_title: Label
var _detail_subtitle: Label
var _detail_effects: VBoxContainer
var _detail_stats: VBoxContainer
var _detail_hint: Label
var _weapon_list: VBoxContainer
var _status_label: Label


func _ready() -> void:
	_build_layout()
	_spawn_preview_data()
	_apply_theme()
	_render_all()


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_root_panel = PanelContainer.new()
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_panel.offset_left = 28
	_root_panel.offset_top = 28
	_root_panel.offset_right = -28
	_root_panel.offset_bottom = -28
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_root_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var title := Label.new()
	title.text = "Weapon Module Workbench"
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	_header_subtitle = Label.new()
	_header_subtitle.text = "Prototype scene for module browsing, compatibility preview, and socket installation."
	header.add_child(_header_subtitle)

	var theme_row := HBoxContainer.new()
	theme_row.add_theme_constant_override("separation", 10)
	root.add_child(theme_row)

	var palette_label := Label.new()
	palette_label.text = "Palette"
	theme_row.add_child(palette_label)

	_theme_selector = OptionButton.new()
	_theme_selector.focus_mode = Control.FOCUS_NONE
	for theme_name in THEME_ORDER:
		_theme_selector.add_item(_format_theme_name(theme_name))
	_theme_selector.item_selected.connect(_on_theme_selected)
	theme_row.add_child(_theme_selector)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	columns.add_child(_build_library_panel())
	columns.add_child(_build_detail_panel())
	columns.add_child(_build_weapon_panel())

	_status_label = Label.new()
	_status_label.text = "Select a module to preview compatible weapons."
	root.add_child(_status_label)

	_preview_root = Node.new()
	_preview_root.name = "PreviewDataRoot"
	add_child(_preview_root)


func _build_library_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("theme_variant", "library")

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	content.add_child(stack)

	var title := Label.new()
	title.text = "Module Library"
	title.add_theme_font_size_override("font_size", 22)
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Cards show effect summary, level, and whether the currently previewed weapon can equip them."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = _theme_color("text_muted")
	stack.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_library_grid = GridContainer.new()
	_library_grid.columns = 2
	_library_grid.add_theme_constant_override("h_separation", 12)
	_library_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_library_grid)

	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("theme_variant", "detail")

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 20)
	content.add_theme_constant_override("margin_top", 20)
	content.add_theme_constant_override("margin_right", 20)
	content.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	content.add_child(stack)

	var kicker := Label.new()
	kicker.text = "DETAIL / PREVIEW"
	kicker.modulate = _theme_color("accent_alt")
	stack.add_child(kicker)

	_detail_title = Label.new()
	_detail_title.text = "Select a Module"
	_detail_title.add_theme_font_size_override("font_size", 24)
	stack.add_child(_detail_title)

	_detail_subtitle = Label.new()
	_detail_subtitle.text = "Hover or click a module card to inspect its role, compatibility, and projected stat changes."
	_detail_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_subtitle.modulate = _theme_color("text_muted")
	stack.add_child(_detail_subtitle)

	var effect_panel := PanelContainer.new()
	effect_panel.set_meta("theme_variant", "deep")
	stack.add_child(effect_panel)

	var effect_margin := MarginContainer.new()
	effect_margin.add_theme_constant_override("margin_left", 14)
	effect_margin.add_theme_constant_override("margin_top", 14)
	effect_margin.add_theme_constant_override("margin_right", 14)
	effect_margin.add_theme_constant_override("margin_bottom", 14)
	effect_panel.add_child(effect_margin)

	_detail_effects = VBoxContainer.new()
	_detail_effects.add_theme_constant_override("separation", 8)
	effect_margin.add_child(_detail_effects)

	var stat_panel := PanelContainer.new()
	stat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_panel.set_meta("theme_variant", "deep")
	stack.add_child(stat_panel)

	var stat_margin := MarginContainer.new()
	stat_margin.add_theme_constant_override("margin_left", 14)
	stat_margin.add_theme_constant_override("margin_top", 14)
	stat_margin.add_theme_constant_override("margin_right", 14)
	stat_margin.add_theme_constant_override("margin_bottom", 14)
	stat_panel.add_child(stat_margin)

	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 8)
	stat_margin.add_child(_detail_stats)

	_detail_hint = Label.new()
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_hint.modulate = _theme_color("accent")
	stack.add_child(_detail_hint)

	return panel


func _build_weapon_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("theme_variant", "library")

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_top", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	content.add_child(stack)

	var title := Label.new()
	title.text = "Weapon Dock"
	title.add_theme_font_size_override("font_size", 22)
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Click INSTALL to socket the selected module. Click REMOVE on an equipped module to send it back to the library."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = _theme_color("text_muted")
	stack.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_weapon_list = VBoxContainer.new()
	_weapon_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_weapon_list)

	return panel


func _spawn_preview_data() -> void:
	_clear_preview_data()

	for scene_index in SAMPLE_WEAPON_SCENES.size():
		var weapon := SAMPLE_WEAPON_SCENES[scene_index].instantiate() as Weapon
		if weapon == null:
			continue
		weapon.name = "PreviewWeapon%d" % scene_index
		_hide_canvas_item(weapon)
		_preview_root.add_child(weapon)
		if weapon.has_method("set_level"):
			weapon.set_level(min(scene_index + 1, 3))
		_attach_pre_equipped_module(weapon, scene_index)
		_sample_weapons.append(weapon)

	for module_index in SAMPLE_MODULE_SCENES.size():
		var module_instance := SAMPLE_MODULE_SCENES[module_index].instantiate() as Module
		if module_instance == null:
			continue
		module_instance.name = "PreviewModule%d" % module_index
		module_instance.set_module_level((module_index % Module.MAX_LEVEL) + 1)
		_hide_canvas_item(module_instance)
		_preview_root.add_child(module_instance)
		_sample_inventory_modules.append(module_instance)

	if not _sample_inventory_modules.is_empty():
		_selected_module = _sample_inventory_modules[0]
	if not _sample_weapons.is_empty():
		_preview_weapon = _sample_weapons[0]


func _attach_pre_equipped_module(weapon: Weapon, scene_index: int) -> void:
	if weapon == null or scene_index >= PRE_EQUIPPED_MODULE_SCENES.size():
		return
	var module_instance := PRE_EQUIPPED_MODULE_SCENES[scene_index].instantiate() as Module
	if module_instance == null:
		return
	module_instance.set_module_level(min(scene_index + 1, Module.MAX_LEVEL))
	_hide_canvas_item(module_instance)
	weapon.modules.add_child(module_instance)
	weapon.validate_module_compatibility()
	weapon.apply_module_stat_pipeline()


func _clear_preview_data() -> void:
	_sample_inventory_modules.clear()
	_sample_weapons.clear()
	_selected_module = null
	_preview_weapon = null
	for child in _preview_root.get_children():
		child.queue_free()


func _render_all() -> void:
	_apply_theme_to_containers()
	_render_module_library()
	_render_detail_panel()
	_render_weapon_list()


func _render_module_library() -> void:
	for child in _library_grid.get_children():
		child.queue_free()

	for module_instance in _sample_inventory_modules:
		if module_instance == null or not is_instance_valid(module_instance):
			continue
		_library_grid.add_child(_create_module_card(module_instance))


func _render_detail_panel() -> void:
	for child in _detail_effects.get_children():
		child.queue_free()
	for child in _detail_stats.get_children():
		child.queue_free()

	if _selected_module == null or not is_instance_valid(_selected_module):
		_detail_title.text = "Select a Module"
		_detail_subtitle.text = "Preview stat deltas and compatibility before committing a socket."
		_detail_hint.text = "Tip: use a melee and a projectile weapon here to verify compatibility messaging."
		_add_info_row(_detail_effects, "No module selected.", _theme_color("text_muted"))
		_add_info_row(_detail_stats, "Projected stats will appear when both a module and weapon are selected.", _theme_color("text_muted"))
		return

	_detail_title.text = "%s Lv.%d" % [
		_selected_module.get_module_display_name(),
		_selected_module.module_level,
	]

	var role_lines: PackedStringArray = []
	var required_traits := _selected_module.get_normalized_required_weapon_traits()
	if not required_traits.is_empty():
		role_lines.append("Requires: %s" % _join_string_variants(required_traits))
	if _selected_module.supports_melee and _selected_module.supports_ranged:
		role_lines.append("Fits melee and ranged weapons")
	elif _selected_module.supports_melee:
		role_lines.append("Fits melee weapons")
	elif _selected_module.supports_ranged:
		role_lines.append("Fits ranged weapons")
	if role_lines.is_empty():
		role_lines.append("General-purpose module")
	_detail_subtitle.text = _join_string_variants(role_lines, " | ")

	var effect_lines := _selected_module.get_effect_descriptions()
	if effect_lines.is_empty():
		_add_section_title(_detail_effects, "Effects")
		_add_info_row(_detail_effects, "No direct numeric modifiers. This module relies on runtime behavior.", _theme_color("text_muted"))
	else:
		_add_section_title(_detail_effects, "Effects")
		for effect_line in effect_lines:
			_add_info_row(_detail_effects, effect_line, _theme_color("text_body"))

	_add_section_title(_detail_stats, "Projected Stat Delta")
	if _preview_weapon == null or not is_instance_valid(_preview_weapon):
		_add_info_row(_detail_stats, "Select a weapon card to see before / after values.", _theme_color("text_muted"))
		_detail_hint.text = "No weapon selected."
		return

	var compatibility_reason := _selected_module.get_incompatibility_reason(_preview_weapon)
	if compatibility_reason != "":
		_add_info_row(_detail_stats, "Blocked: %s" % compatibility_reason, _theme_color("warning"))
		_detail_hint.text = "%s cannot be installed on %s." % [
			_selected_module.get_module_display_name(),
			_get_weapon_display_name(_preview_weapon),
		]
		return

	var current := _preview_weapon.build_stat_snapshot()
	var projected := _preview_weapon.get_projected_stats_with_module(_selected_module)
	var has_delta := false
	for stat_key in TRACKED_STAT_KEYS:
		if not current.has(stat_key) or not projected.has(stat_key):
			continue
		var before := float(current[stat_key])
		var after := float(projected[stat_key])
		if is_equal_approx(before, after):
			continue
		has_delta = true
		var row_color := _theme_color("success") if after > before else _theme_color("warning")
		if stat_key == "attack_cooldown" and after < before:
			row_color = _theme_color("success")
		_add_info_row(
			_detail_stats,
			"%s  %.2f -> %.2f" % [_format_stat_label(stat_key), before, after],
			row_color
		)
	if not has_delta:
		_add_info_row(_detail_stats, "No tracked stat changes. Treat this as a behavior-only module.", _theme_color("text_muted"))

	_detail_hint.text = "Previewing on %s." % _get_weapon_display_name(_preview_weapon)


func _render_weapon_list() -> void:
	for child in _weapon_list.get_children():
		child.queue_free()

	for weapon in _sample_weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		_weapon_list.add_child(_create_weapon_card(weapon))


func _create_module_card(module_instance: Module) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 152)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE

	var can_fit_preview := _preview_weapon != null and is_instance_valid(_preview_weapon) and module_instance.get_incompatibility_reason(_preview_weapon) == ""
	var border_color := _theme_color("border")
	if module_instance == _selected_module:
		border_color = _theme_color("accent_alt")
	elif can_fit_preview:
		border_color = _theme_color("accent")

	button.add_theme_stylebox_override("normal", _make_panel_style(_theme_color("panel"), border_color, 2, 14))
	button.add_theme_stylebox_override("hover", _make_panel_style(_theme_color("panel_soft"), _theme_color("accent_alt"), 2, 14))
	button.add_theme_stylebox_override("pressed", _make_panel_style(_theme_color("panel_soft"), _theme_color("accent_alt"), 2, 14))

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 12)
	content.add_theme_constant_override("margin_bottom", 12)
	button.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	content.add_child(stack)

	var top_row := HBoxContainer.new()
	stack.add_child(top_row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_module_texture(module_instance)
	top_row.add_child(icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_stack)

	var title := Label.new()
	title.text = module_instance.get_module_display_name()
	title.clip_text = true
	title_stack.add_child(title)

	var badge := Label.new()
	var state_text := "Compatible" if can_fit_preview else "Unscoped"
	if _preview_weapon != null and is_instance_valid(_preview_weapon) and not can_fit_preview:
		state_text = "Blocked"
	badge.text = "Lv.%d  %s" % [module_instance.module_level, state_text]
	badge.modulate = _theme_color("accent") if can_fit_preview else _theme_color("text_muted")
	title_stack.add_child(badge)

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = _join_effect_summary(module_instance)
	summary.modulate = _theme_color("text_body")
	stack.add_child(summary)

	button.pressed.connect(_on_module_selected.bind(module_instance))
	button.mouse_entered.connect(_on_module_hovered.bind(module_instance))
	return button


func _create_weapon_card(weapon: Weapon) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
			_make_panel_style(
			_theme_color("panel"),
			_theme_color("accent_alt") if weapon == _preview_weapon else _theme_color("border"),
			2,
			14
		)
	)

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 14)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	content.add_child(stack)

	var header := HBoxContainer.new()
	stack.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_weapon_texture(weapon)
	header.add_child(icon)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_stack)

	var name_label := Label.new()
	name_label.text = _get_weapon_display_name(weapon)
	name_label.add_theme_font_size_override("font_size", 20)
	title_stack.add_child(name_label)

	var trait_label := Label.new()
	trait_label.text = "Traits: %s" % _join_string_variants(weapon.get_normalized_weapon_traits())
	trait_label.modulate = _theme_color("text_muted")
	title_stack.add_child(trait_label)

	var action_button := Button.new()
	action_button.text = "INSTALL"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.custom_minimum_size = Vector2(96, 34)
	header.add_child(action_button)

	var feedback := {}
	var can_equip := false
	if _selected_module != null and is_instance_valid(_selected_module):
		feedback = {
			"ok": _selected_module.get_incompatibility_reason(weapon) == "" and weapon.get_available_module_slots() > 0
		}
		if not feedback["ok"]:
			var reason := _selected_module.get_incompatibility_reason(weapon)
			if reason == "" and weapon.get_available_module_slots() <= 0:
				reason = "No module slots available."
			feedback["reason"] = reason
		can_equip = bool(feedback.get("ok", false))

	action_button.disabled = not can_equip
	action_button.add_theme_color_override("font_color", _theme_color("button_text"))
	action_button.add_theme_color_override("font_disabled_color", _theme_color("text_muted").darkened(0.2))
	action_button.add_theme_stylebox_override("normal", _make_button_style(_theme_color("button_fill") if can_equip else _theme_color("button_disabled")))
	action_button.add_theme_stylebox_override("disabled", _make_button_style(_theme_color("button_disabled")))
	action_button.pressed.connect(_on_install_pressed.bind(weapon))
	action_button.mouse_entered.connect(_on_weapon_previewed.bind(weapon))

	var sockets := HBoxContainer.new()
	sockets.add_theme_constant_override("separation", 10)
	stack.add_child(sockets)

	var equipped_modules := weapon.get_equipped_modules()
	for slot_index in weapon.MAX_MODULE_NUMBER:
		sockets.add_child(_create_socket_badge(weapon, slot_index, equipped_modules))

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = _get_weapon_module_summary(weapon)
	stack.add_child(summary)

	var preview := Label.new()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.modulate = _theme_color("accent") if can_equip else _theme_color("text_muted")
	preview.text = _get_weapon_preview_summary(weapon, feedback)
	stack.add_child(preview)

	panel.mouse_entered.connect(_on_weapon_previewed.bind(weapon))
	return panel


func _create_socket_badge(weapon: Weapon, slot_index: int, equipped_modules: Array[Module]) -> Control:
	var socket_button := Button.new()
	socket_button.flat = true
	socket_button.focus_mode = Control.FOCUS_NONE
	socket_button.custom_minimum_size = Vector2(90, 74)

	var has_module := slot_index < equipped_modules.size()
	var module_instance: Module = equipped_modules[slot_index] if has_module else null
	var border_color := _theme_color("border")
	var fill_color := _theme_color("panel_alt")
	if has_module:
		border_color = _theme_color("accent_alt")
		fill_color = _theme_color("socket_full_fill")
	elif _selected_module != null and is_instance_valid(_selected_module):
		var reason := _selected_module.get_incompatibility_reason(weapon)
		if reason == "" and weapon.get_available_module_slots() > 0:
			border_color = _theme_color("accent")
			fill_color = _theme_color("socket_ready_fill")
		else:
			border_color = _theme_color("warning")
			fill_color = _theme_color("socket_blocked_fill")

	socket_button.add_theme_stylebox_override("normal", _make_panel_style(fill_color, border_color, 2, 12))
	socket_button.add_theme_stylebox_override("hover", _make_panel_style(fill_color.lightened(0.08), _theme_color("accent_alt"), 2, 12))
	socket_button.add_theme_stylebox_override("pressed", _make_panel_style(fill_color.lightened(0.08), _theme_color("accent_alt"), 2, 12))

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 8)
	socket_button.add_child(content)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	content.add_child(stack)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(label)

	if has_module and module_instance != null:
		icon.texture = _get_module_texture(module_instance)
		label.text = "REMOVE"
		socket_button.pressed.connect(_on_remove_pressed.bind(weapon, module_instance))
	else:
		label.text = "EMPTY"
		socket_button.disabled = true

	socket_button.mouse_entered.connect(_on_weapon_previewed.bind(weapon))
	return socket_button


func _on_module_selected(module_instance: Module) -> void:
	_selected_module = module_instance
	_status_label.text = "Selected %s Lv.%d." % [
		module_instance.get_module_display_name(),
		module_instance.module_level,
	]
	_status_label.modulate = _theme_color("accent")
	_render_all()


func _on_module_hovered(module_instance: Module) -> void:
	if _selected_module == module_instance:
		return
	_selected_module = module_instance
	_render_all()


func _on_weapon_previewed(weapon: Weapon) -> void:
	_preview_weapon = weapon
	_render_all()


func _on_install_pressed(weapon: Weapon) -> void:
	if _selected_module == null or not is_instance_valid(_selected_module):
		return
	var reason := _selected_module.get_incompatibility_reason(weapon)
	if reason != "":
		_status_label.text = "Blocked: %s" % reason
		_status_label.modulate = _theme_color("warning")
		_render_all()
		return
	if weapon.get_available_module_slots() <= 0:
		_status_label.text = "Blocked: No module slots available."
		_status_label.modulate = _theme_color("warning")
		_render_all()
		return
	_sample_inventory_modules.erase(_selected_module)
	_selected_module.reparent(weapon.modules)
	weapon.validate_module_compatibility()
	weapon.apply_module_stat_pipeline()
	_status_label.text = "Installed %s on %s." % [
		_selected_module.get_module_display_name(),
		_get_weapon_display_name(weapon),
	]
	_status_label.modulate = _theme_color("accent")
	_preview_weapon = weapon
	_selected_module = _sample_inventory_modules[0] if not _sample_inventory_modules.is_empty() else null
	_render_all()


func _on_remove_pressed(weapon: Weapon, module_instance: Module) -> void:
	if weapon == null or module_instance == null:
		return
	module_instance.reparent(_preview_root)
	_hide_canvas_item(module_instance)
	_sample_inventory_modules.append(module_instance)
	weapon.apply_module_stat_pipeline()
	_preview_weapon = weapon
	_selected_module = module_instance
	_status_label.text = "Removed %s from %s." % [
		module_instance.get_module_display_name(),
		_get_weapon_display_name(weapon),
	]
	_status_label.modulate = _theme_color("accent_alt")
	_render_all()


func _get_weapon_module_summary(weapon: Weapon) -> String:
	var names: PackedStringArray = []
	for module_instance in weapon.get_equipped_modules():
		names.append("%s Lv.%d" % [module_instance.get_module_display_name(), module_instance.module_level])
	if names.is_empty():
		return "Socketed modules: none"
	return "Socketed modules: %s" % _join_string_variants(names)


func _get_weapon_preview_summary(weapon: Weapon, feedback: Dictionary) -> String:
	if _selected_module == null or not is_instance_valid(_selected_module):
		return "Select a module to compare against this weapon."
	if bool(feedback.get("ok", false)):
		var current := weapon.build_stat_snapshot()
		var projected := weapon.get_projected_stats_with_module(_selected_module)
		var deltas: PackedStringArray = []
		for stat_key in TRACKED_STAT_KEYS:
			if not current.has(stat_key) or not projected.has(stat_key):
				continue
			var before := float(current[stat_key])
			var after := float(projected[stat_key])
			if is_equal_approx(before, after):
				continue
			deltas.append("%s %.2f -> %.2f" % [_format_stat_label(stat_key), before, after])
		if deltas.is_empty():
			return "Compatible. No tracked numeric deltas, likely a behavior module."
		return "Compatible. %s" % _join_string_variants(deltas, " | ")
	return "Blocked. %s" % str(feedback.get("reason", "Unknown reason"))


func _join_effect_summary(module_instance: Module) -> String:
	var effect_lines := module_instance.get_effect_descriptions()
	if effect_lines.is_empty():
		return "Behavior module with no direct tracked stat modifier."
	return _join_string_variants(effect_lines, " / ")


func _get_weapon_display_name(weapon: Weapon) -> String:
	var item_name: Variant = weapon.get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		return str(item_name)
	return weapon.name


func _get_weapon_texture(weapon: Weapon) -> Texture2D:
	var sprite_node := weapon.get_node_or_null("Sprite") as Sprite2D
	return sprite_node.texture if sprite_node else null


func _get_module_texture(module_instance: Module) -> Texture2D:
	var sprite_node := module_instance.get_node_or_null("%Sprite") as Sprite2D
	return sprite_node.texture if sprite_node else null


func _format_stat_label(stat_key: String) -> String:
	return stat_key.replace("_", " ").capitalize()


func _join_string_variants(values, separator: String = ", ") -> String:
	var parts: PackedStringArray = []
	for value in values:
		parts.append(str(value))
	return separator.join(parts)


func _hide_canvas_item(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = false


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = _theme_color("accent_alt")
	parent.add_child(label)


func _add_info_row(parent: VBoxContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = color
	parent.add_child(label)


func _make_panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _make_button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_theme() -> void:
	_background.color = _theme_color("bg")
	_root_panel.add_theme_stylebox_override("panel", _make_panel_style(_theme_color("panel"), _theme_color("accent"), 2, 18))
	_header_subtitle.modulate = _theme_color("text_muted")
	_detail_subtitle.modulate = _theme_color("text_muted")
	_detail_hint.modulate = _theme_color("accent")
	_status_label.modulate = _theme_color("accent")
	if _theme_selector != null:
		_theme_selector.select(max(THEME_ORDER.find(_theme_key), 0))


func _apply_theme_to_containers() -> void:
	for child in get_children():
		_apply_theme_recursive(child)


func _apply_theme_recursive(node: Node) -> void:
	if node is PanelContainer:
		var panel_node := node as PanelContainer
		var variant := str(panel_node.get_meta("theme_variant", "library"))
		match variant:
			"detail":
				panel_node.add_theme_stylebox_override("panel", _make_panel_style(_theme_color("panel_soft"), _theme_color("accent_alt"), 1, 16))
			"deep":
				panel_node.add_theme_stylebox_override("panel", _make_panel_style(_theme_color("panel_deep"), _theme_color("border"), 1, 12))
			_:
				panel_node.add_theme_stylebox_override("panel", _make_panel_style(_theme_color("panel_alt"), _theme_color("border"), 1, 16))
	for child in node.get_children():
		_apply_theme_recursive(child)


func _on_theme_selected(index: int) -> void:
	if index < 0 or index >= THEME_ORDER.size():
		return
	_theme_key = THEME_ORDER[index]
	_apply_theme()
	_render_all()


func _theme_color(key: String) -> Color:
	return THEMES.get(_theme_key, THEMES["teal_hangar"]).get(key, Color.WHITE)


func _format_theme_name(theme_name: String) -> String:
	return theme_name.replace("_", " ").capitalize()
