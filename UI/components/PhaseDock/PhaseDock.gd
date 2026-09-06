extends PanelContainer

@onready var phase_label: Label = %PhaseLabel
@onready var content_row: HBoxContainer = %ContentRow


func set_phase_text(text: String) -> void:
	phase_label.text = text


func get_content_row() -> HBoxContainer:
	return content_row
