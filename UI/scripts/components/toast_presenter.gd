extends RefCounted
class_name ToastPresenter

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")

var owner_ui: UI
var panel: PanelContainer
var label: Label
var _generation := 0
var _tween: Tween


func bind(ui: UI) -> void:
	owner_ui = ui
	_ensure_view()


func show_message(text: String, duration: float = 1.8) -> void:
	_ensure_view()
	if panel == null:
		return
	_generation += 1
	var generation := _generation
	if _tween != null and _tween.is_valid():
		_tween.kill()
	layout(owner_ui.get_viewport().get_visible_rect().size)
	label.text = text
	panel.visible = not text.is_empty()
	panel.modulate.a = 0.0
	panel.position.y += 6.0
	_tween = owner_ui.create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	_tween.tween_property(panel, "position:y", panel.position.y - 6.0, 0.18)
	await owner_ui.get_tree().create_timer(maxf(duration, 0.1)).timeout
	if generation != _generation or panel == null:
		return
	_tween = owner_ui.create_tween()
	_tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(_hide.bind(generation))


func layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	var width := minf(440.0, maxf(240.0, viewport_size.x - 720.0))
	panel.position = Vector2(roundf((viewport_size.x - width) * 0.5), 86.0)
	panel.size = Vector2(width, 44.0)


func clear() -> void:
	_generation += 1
	if panel != null:
		panel.visible = false
		panel.modulate.a = 1.0


func _ensure_view() -> void:
	if owner_ui == null or panel != null:
		return
	panel = PanelContainer.new()
	panel.name = "ToastDock"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 90
	var style := TOKENS.make_panel_style(true, TOKENS.COLOR_ACCENT_SYSTEM)
	style.bg_color = Color(0.02, 0.08, 0.11, 0.94)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TOKENS.style_label(label, TOKENS.FONT_BODY, TOKENS.COLOR_TEXT_PRIMARY)
	margin.add_child(label)
	owner_ui.gui_root.add_child(panel)
	panel.visible = false
	layout(owner_ui.get_viewport().get_visible_rect().size)


func _hide(generation: int) -> void:
	if generation == _generation and panel != null:
		panel.visible = false
		panel.modulate.a = 1.0
