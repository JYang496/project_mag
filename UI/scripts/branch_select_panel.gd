extends Control
class_name BranchSelectPanel

const BRANCH_CARD_SCENE := preload("res://UI/components/BranchCard/BranchCard.tscn")

signal branch_selected(weapon: Weapon, branch_id: String)

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: Control = $Panel/VBox/Options
@onready var panel: Panel = $Panel

var _weapon: Weapon
var _branch_ids: Array[String] = []
var _branch_defs_cache: Array[WeaponBranchDefinition] = []

func _ready() -> void:
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if not ModalUiController.is_cancel_input(event):
		return
	get_viewport().set_input_as_handled()

func open_for_weapon(target_weapon: Weapon, branch_defs: Array[WeaponBranchDefinition]) -> void:
	_weapon = target_weapon
	_branch_ids.clear()
	_branch_defs_cache = branch_defs.duplicate()
	visible = true
	if _weapon and is_instance_valid(_weapon):
		title_label.text = LocalizationManager.tr_key("ui.branch.title", "Choose Evolution Branch")
		var weapon_name := LocalizationManager.get_weapon_instance_display_name(_weapon)
		var selected_summary := _build_selected_branch_summary(_weapon)
		subtitle_label.text = weapon_name if weapon_name != "" else LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		if selected_summary != "":
			subtitle_label.text += "\n" + selected_summary
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
	for def in sorted_defs:
		_branch_ids.append(def.branch_id)
		var branch_card := _build_branch_card(def)
		options_box.add_child(branch_card)

func close_panel(_choose_default_if_pending: bool = false) -> void:
	visible = false
	_weapon = null
	_branch_ids.clear()

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return false

func cancel_visible_modal() -> bool:
	return false

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
	if int(a.sort_order) != int(b.sort_order):
		return int(a.sort_order) < int(b.sort_order)
	var name_a := LocalizationManager.get_branch_display_name(a).to_lower()
	var name_b := LocalizationManager.get_branch_display_name(b).to_lower()
	if name_a == name_b:
		return str(a.branch_id) < str(b.branch_id)
	return name_a < name_b

func _build_branch_card(def: WeaponBranchDefinition) -> Button:
	var button := BRANCH_CARD_SCENE.instantiate() as Button
	var fuse_text := LocalizationManager.tr_format(
		"ui.weapon.fuse_value",
		{"fuse": int(def.unlock_fuse)},
		"Fuse %d" % int(def.unlock_fuse)
	).to_upper()
	button.call("set_data", {"id": def.branch_id, "name": LocalizationManager.get_branch_display_name(def), "description": LocalizationManager.get_branch_description(def), "icon": def.icon, "accent": _get_branch_accent(def), "fuse": fuse_text})
	button.connect("selected", _on_branch_button_pressed)
	return button

func _build_selected_branch_summary(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var selected_ids: Array = weapon.branch_runtime.branch_ids
	if selected_ids.is_empty():
		return LocalizationManager.tr_key("ui.branch.selected_none", "Selected branches: none")
	var parts: PackedStringArray = []
	for branch_id_variant in selected_ids:
		var branch_id := str(branch_id_variant)
		var def := DataHandler.read_weapon_branch_definition(weapon.scene_file_path, branch_id)
		if def == null:
			parts.append(branch_id)
		else:
			parts.append(LocalizationManager.get_branch_display_name(def))
	return LocalizationManager.tr_format(
		"ui.branch.selected_summary",
		{"branches": ", ".join(parts)},
		"Selected branches: %s" % ", ".join(parts)
	)

func _get_branch_accent(def: WeaponBranchDefinition) -> Color:
	var text := ("%s %s %s" % [def.branch_id, def.display_name, def.description]).to_lower()
	if text.contains("fire") or text.contains("thermal") or text.contains("napalm") or text.contains("explosive"):
		return Color(1.0, 0.42, 0.18)
	if text.contains("frost") or text.contains("cryo") or text.contains("freeze") or text.contains("subzero") or text.contains("ice"):
		return Color(0.32, 0.78, 1.0)
	if text.contains("energy") or text.contains("arc") or text.contains("laser") or text.contains("plasma") or text.contains("prism"):
		return Color(0.56, 0.72, 1.0)
	if text.contains("shield") or text.contains("guard"):
		return Color(0.52, 0.9, 0.66)
	if text.contains("pierce") or text.contains("lance") or text.contains("focus"):
		return Color(0.86, 0.72, 1.0)
	return Color(0.86, 0.72, 0.34)
