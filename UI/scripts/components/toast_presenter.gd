extends RefCounted
class_name ToastPresenter

const TOAST_DOCK_SCENE := preload("res://UI/components/ToastDock/ToastDock.tscn")

var owner_ui: UI
var panel: PanelContainer
var label: Label


func bind(ui: UI) -> void:
	owner_ui = ui
	_ensure_view()


func show_message(text: String, duration: float = 1.8) -> void:
	_ensure_view()
	if panel == null:
		return
	panel.call("show_message", text, duration)


func layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	panel.call("layout_in", viewport_size)


func clear() -> void:
	if panel != null:
		panel.call("clear")


func _ensure_view() -> void:
	if owner_ui == null or panel != null:
		return
	panel = TOAST_DOCK_SCENE.instantiate() as PanelContainer
	panel.z_index = 90
	owner_ui.gui_root.add_child(panel)
	label = panel.get_node("Margin/Message") as Label
	layout(owner_ui.get_viewport().get_visible_rect().size)
