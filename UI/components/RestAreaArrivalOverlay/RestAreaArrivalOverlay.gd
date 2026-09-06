extends Control

@onready var scrim: ColorRect = %Scrim
@onready var scan_line: ColorRect = %ScanLine
@onready var status_panel: PanelContainer = %StatusPanel
@onready var status_label: Label = %StatusLabel
@onready var progress_fill: ColorRect = %ProgressFill
@onready var audio_player: AudioStreamPlayer = %AudioPlayer


func set_status(text: String) -> void:
	status_label.text = text


func set_progress(value: float) -> void:
	progress_fill.scale.x = clampf(value, 0.0, 1.0)
