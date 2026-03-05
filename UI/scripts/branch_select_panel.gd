extends Control
class_name BranchSelectPanel

signal branch_selected(weapon: Weapon, branch_id: String)

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: VBoxContainer = $Panel/VBox/Options

var _weapon: Weapon
var _branch_ids: Array[String] = []

func open_for_weapon(target_weapon: Weapon, branch_defs: Array[WeaponBranchDefinition]) -> void:
	_weapon = target_weapon
	_branch_ids.clear()
	visible = true
	if _weapon and is_instance_valid(_weapon):
		var item_name: Variant = _weapon.get("ITEM_NAME")
		title_label.text = "Choose Evolution Branch"
		subtitle_label.text = str(item_name) if item_name != null else "Weapon"
	else:
		title_label.text = "Choose Evolution Branch"
		subtitle_label.text = ""
	for child in options_box.get_children():
		child.queue_free()
	for def in branch_defs:
		_branch_ids.append(def.branch_id)
		var button := Button.new()
		button.text = "%s - %s" % [def.display_name, def.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 64)
		button.pressed.connect(Callable(self, "_on_branch_button_pressed").bind(def.branch_id))
		options_box.add_child(button)

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
