extends PanelContainer

@onready var title_label: Label = %Title
@onready var value_label: Label = %Value
@onready var detail_label: Label = %Detail
@onready var progress_bar: ProgressBar = %Progress
@onready var audio_player: AudioStreamPlayer = %AudioPlayer


func set_expanded(expanded: bool) -> void:
	detail_label.visible = expanded
	custom_minimum_size = Vector2(280.0, 120.0) if expanded else Vector2(280.0, 80.0)
