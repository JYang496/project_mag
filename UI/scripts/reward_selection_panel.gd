extends Control
class_name RewardSelectionPanel

signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: VBoxContainer = $Panel/VBox/Options
@onready var confirm_button: Button = $Panel/VBox/Footer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Footer/CancelButton

var _reward_options: Array[RewardInfo] = []
var _selected_index: int = -1
var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)

func open_for_rewards(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if reward_options.is_empty():
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_selected_index = -1
	_reward_options.clear()
	title_label.text = "Choose Reward"
	subtitle_label.text = "%s - pick one reward." % route_display_name
	for child in options_box.get_children():
		child.queue_free()
	for reward in reward_options:
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	for idx in range(_reward_options.size()):
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 58)
		button.text = _build_reward_summary(_reward_options[idx])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
		options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_confirm_button_state()
	visible = true
	return true

func close_panel() -> void:
	visible = false
	_reward_options.clear()
	_selected_index = -1
	_on_confirm = Callable()
	_on_cancel = Callable()

func _on_reward_button_pressed(index: int, source_button: Button) -> void:
	_selected_index = index
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.button_pressed = (button == source_button)
	_confirm_button_state()

func _confirm_button_state() -> void:
	confirm_button.disabled = _selected_index < 0 or _selected_index >= _reward_options.size()

func _on_confirm_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _reward_options.size():
		return
	var reward := _reward_options[_selected_index]
	reward_confirmed.emit(reward)
	if _on_confirm.is_valid():
		_on_confirm.call_deferred(reward)
	close_panel()

func _on_cancel_pressed() -> void:
	selection_cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call_deferred()
	close_panel()

func _build_reward_summary(reward: RewardInfo) -> String:
	var chunks: PackedStringArray = []
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		chunks.append("Weapon #%s Lv.%d" % [reward.item_id, reward.item_level])
	if reward.module_scene:
		var module_name := _extract_scene_name(reward.module_scene.resource_path)
		chunks.append("Module %s Lv.%d" % [module_name, max(1, reward.module_level)])
	if reward.total_chip_value > 0:
		chunks.append("EXP +%d" % reward.total_chip_value)
	if chunks.is_empty():
		return "Reward"
	return " + ".join(chunks)

func _extract_scene_name(scene_path: String) -> String:
	if scene_path == "":
		return "Unknown"
	var file_name := scene_path.get_file().get_basename()
	if file_name == "":
		return "Unknown"
	return file_name.replace("_", " ").capitalize()
