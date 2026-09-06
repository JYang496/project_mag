extends PanelContainer

@onready var title_label: Label = %Title
@onready var objective_label: Label = %Objective
@onready var parameters_label: Label = %Parameters


func set_data(title: String, objective: String, parameters: String) -> void:
	title_label.text = title
	objective_label.text = objective
	parameters_label.text = parameters
