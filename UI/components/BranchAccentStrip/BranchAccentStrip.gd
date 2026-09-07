extends Control

@onready var segments: Array[ColorRect] = [$BranchAccentStrip/SegmentOne, $BranchAccentStrip/SegmentTwo]


func set_data(colors: Array) -> void:
	if segments.is_empty() or segments[0] == null:
		segments = [get_node("BranchAccentStrip/SegmentOne"), get_node("BranchAccentStrip/SegmentTwo")]
	for index in range(2):
		segments[index].visible = index < colors.size()
		if segments[index].visible:
			segments[index].color = colors[index] as Color
