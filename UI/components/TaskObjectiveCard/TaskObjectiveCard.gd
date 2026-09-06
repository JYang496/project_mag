extends PanelContainer

@onready var marker: Label = %Marker
@onready var title_label: Label = %Title
@onready var value_label: Label = %Value
@onready var instruction_label: Label = %Instruction
@onready var progress_bar: ProgressBar = %Progress


func set_data(data: Dictionary, compact: bool = false) -> void:
	var state := str(data.get("state", "active")).strip_edges().to_lower()
	var instruction := _sanitize(str(data.get("instruction", "")), 36, "")
	title_label.text = _sanitize(str(data.get("label", "")), 24, "Task")
	value_label.text = _sanitize(str(data.get("value_text", "")), 24, "")
	instruction_label.text = instruction
	instruction_label.visible = not compact and not instruction.is_empty()
	progress_bar.visible = not compact
	progress_bar.call("set_target_value", clampf(float(data.get("progress", 0.0)), 0.0, 1.0))
	_set_marker(str(data.get("icon_key", data.get("type", ""))), state)
	_set_state(state)


func _sanitize(text: String, maximum: int, fallback: String) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	var lower := clean.to_lower()
	if clean.is_empty() or lower.contains("quest:") or lower.contains("remaining"):
		return fallback
	if clean.length() > maximum:
		return clean.substr(0, maximum - 1) + "..."
	return clean


func _set_marker(key: String, state: String) -> void:
	var normalized := key.strip_edges().to_lower()
	var text := "?"
	var tooltip := "Task"
	var color := Color(0.54, 0.64, 0.72, 1.0)
	match normalized:
		"kill", "offense": text = "K"; tooltip = "Kill"; color = Color(0.96, 0.42, 0.32, 1.0)
		"hold", "defense": text = "H"; tooltip = "Hold"; color = Color(0.38, 0.72, 1.0, 1.0)
		"clear": text = "C"; tooltip = "Clear"; color = Color(0.58, 0.84, 0.46, 1.0)
		"hunt": text = "E"; tooltip = "Hunt"; color = Color(0.92, 0.62, 0.26, 1.0)
		"dodge": text = "D"; tooltip = "Dodge"; color = Color(0.72, 0.56, 1.0, 1.0)
	if state in ["complete", "completed"]: color = Color(0.58, 1.0, 0.55, 1.0)
	elif state in ["waiting", "blocked"]: color = Color(0.45, 0.52, 0.56, 1.0)
	marker.text = text
	marker.tooltip_text = tooltip
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.20)
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	marker.add_theme_stylebox_override("normal", style)


func _set_state(state: String) -> void:
	var background := Color(0.08, 0.11, 0.13, 0.74)
	var border := Color(0.30, 0.46, 0.54, 0.78)
	var fill := Color(0.35, 0.84, 0.70, 0.95)
	modulate = Color.WHITE
	if state in ["complete", "completed"]:
		modulate = Color(0.70, 0.88, 0.75, 0.82)
		background = Color(0.07, 0.12, 0.09, 0.68); border = Color(0.34, 0.62, 0.42, 0.62); fill = Color(0.42, 0.78, 0.48, 0.78)
	elif state in ["waiting", "blocked"]:
		modulate = Color(0.72, 0.76, 0.78, 0.82)
		background = Color(0.08, 0.10, 0.12, 0.72); border = Color(0.24, 0.31, 0.35, 0.68); fill = Color(0.38, 0.48, 0.52, 0.9)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = background; panel_style.border_color = border
	panel_style.set_border_width_all(1); panel_style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", panel_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill; fill_style.set_corner_radius_all(2)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
