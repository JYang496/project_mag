extends Control
class_name BranchSelectPanel

signal branch_selected(weapon: Weapon, branch_id: String)

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: Control = $Panel/VBox/Options

var _weapon: Weapon
var _branch_ids: Array[String] = []
var _branch_defs_cache: Array[WeaponBranchDefinition] = []

func _ready() -> void:
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_for_weapon(target_weapon: Weapon, branch_defs: Array[WeaponBranchDefinition]) -> void:
	_weapon = target_weapon
	_branch_ids.clear()
	_branch_defs_cache = branch_defs.duplicate()
	visible = true
	if _weapon and is_instance_valid(_weapon):
		title_label.text = LocalizationManager.tr_key("ui.branch.title", "Choose Evolution Branch")
		var weapon_name := LocalizationManager.get_weapon_name_from_node(_weapon)
		subtitle_label.text = weapon_name if weapon_name != "" else LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
	else:
		title_label.text = LocalizationManager.tr_key("ui.branch.title", "Choose Evolution Branch")
		subtitle_label.text = ""
	for child in options_box.get_children():
		child.queue_free()
	var sorted_defs: Array[WeaponBranchDefinition] = []
	for def in branch_defs:
		if def == null:
			continue
		sorted_defs.append(def)
	sorted_defs.sort_custom(Callable(self, "_sort_branch_defs"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_box.add_child(row)
	for def in sorted_defs:
		_branch_ids.append(def.branch_id)
		var branch_card := _build_branch_card(def)
		row.add_child(branch_card)

func close_panel(choose_default_if_pending: bool = false) -> void:
	if choose_default_if_pending and _weapon and is_instance_valid(_weapon) and not _branch_ids.is_empty():
		branch_selected.emit(_weapon, _branch_ids[0])
	visible = false
	_weapon = null
	_branch_ids.clear()

func _on_branch_button_pressed(branch_id: String) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		close_panel()
		return
	branch_selected.emit(_weapon, branch_id)
	close_panel(false)

func _on_language_changed(_locale: String) -> void:
	if visible:
		open_for_weapon(_weapon, _branch_defs_cache)

func _sort_branch_defs(a: WeaponBranchDefinition, b: WeaponBranchDefinition) -> bool:
	var name_a := LocalizationManager.get_branch_display_name(a).to_lower()
	var name_b := LocalizationManager.get_branch_display_name(b).to_lower()
	if name_a == name_b:
		return str(a.branch_id) < str(b.branch_id)
	return name_a < name_b

func _build_branch_card(def: WeaponBranchDefinition) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(160, 220)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, "_on_branch_button_pressed").bind(def.branch_id))

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 10)
	button.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = LocalizationManager.get_branch_display_name(def)
	vbox.add_child(name_label)

	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(96, 72)
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = def.icon
	vbox.add_child(icon_rect)

	var desc_label := Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = LocalizationManager.get_branch_description(def)
	vbox.add_child(desc_label)

	return button
