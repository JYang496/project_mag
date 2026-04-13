extends Control
class_name RouteSelectionPanel

signal route_confirmed(route_id: String)
signal selection_cancelled

@onready var title_label: Label = $Panel/VBox/Title
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_box: VBoxContainer = $Panel/VBox/Options
@onready var confirm_button: Button = $Panel/VBox/Footer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Footer/CancelButton

var _selected_route_id: String = ""
var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()
var _route_defs_cache: Array[RunRouteDefinition] = []
var _default_route_id_cache: String = ""

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)

func open_for_routes(
	route_defs: Array[RunRouteDefinition],
	default_route_id: String,
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable()
) -> bool:
	if route_defs.is_empty():
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_route_defs_cache = route_defs.duplicate()
	_default_route_id_cache = default_route_id
	_selected_route_id = ""
	title_label.text = LocalizationManager.tr_key("ui.route.title", "Choose Route")
	subtitle_label.text = LocalizationManager.tr_key("ui.route.subtitle", "Select one route for this level.")
	confirm_button.text = LocalizationManager.tr_key("ui.route.confirm", "Confirm Route")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	for child in options_box.get_children():
		child.queue_free()
	for route_def in route_defs:
		if route_def == null:
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 64)
		button.set_meta("route_id", route_def.route_id)
		button.text = "%s\n%s" % [
			LocalizationManager.get_route_display_name(route_def),
			LocalizationManager.get_route_description(route_def)
		]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(Callable(self, "_on_route_button_pressed").bind(route_def.route_id, button))
		options_box.add_child(button)
		if _selected_route_id == "" and route_def.route_id == default_route_id:
			_on_route_button_pressed(route_def.route_id, button)
	if _selected_route_id == "" and options_box.get_child_count() > 0:
		var first_button := options_box.get_child(0) as Button
		if first_button:
			var first_route_id := str(first_button.get_meta("route_id", ""))
			if first_route_id != "":
				_on_route_button_pressed(first_route_id, first_button)
	_confirm_button_state()
	visible = true
	return true

func close_panel() -> void:
	visible = false
	_selected_route_id = ""
	_on_confirm = Callable()
	_on_cancel = Callable()

func _on_route_button_pressed(route_id: String, source_button: Button) -> void:
	_selected_route_id = route_id
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		button.button_pressed = (button == source_button)
	_confirm_button_state()

func _confirm_button_state() -> void:
	confirm_button.disabled = _selected_route_id == ""

func _on_confirm_pressed() -> void:
	if _selected_route_id == "":
		return
	route_confirmed.emit(_selected_route_id)
	if _on_confirm.is_valid():
		_on_confirm.call_deferred(_selected_route_id)
	close_panel()

func _on_cancel_pressed() -> void:
	selection_cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call_deferred()
	close_panel()

func _on_language_changed(_locale: String) -> void:
	if visible:
		open_for_routes(_route_defs_cache, _default_route_id_cache, _on_confirm, _on_cancel)
