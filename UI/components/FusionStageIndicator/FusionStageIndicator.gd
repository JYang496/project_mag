extends VBoxContainer

const PIP_SCENE := preload("res://UI/components/FusionStagePip/FusionStagePip.tscn")

@onready var title_label: Label = %Title
@onready var stages: HBoxContainer = %Stages
@onready var caption: Label = %Caption


func set_data(title_text: String, caption_text: String, stage_data: Array) -> void:
	title_label.text = title_text
	caption.text = caption_text
	for item in stage_data:
		var data := item as Dictionary
		var pip := PIP_SCENE.instantiate() as Label
		stages.add_child(pip)
		pip.call("set_data", str(data.get("text", "")), data.get("color", Color.WHITE) as Color, data.get("style") as StyleBox)
