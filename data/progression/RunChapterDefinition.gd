extends Resource
class_name RunChapterDefinition

@export var chapter_id: StringName = &""
@export var title_key := ""
@export var title_fallback := ""
@export var subtitle_key := ""
@export var subtitle_fallback := ""
@export var start_level_index: int = 0
@export var end_level_index: int = 0
@export var theme_id: StringName = &""
@export var board_active_cell_ids: PackedInt32Array = PackedInt32Array()
@export var rest_after_completion := true

func contains_level(level_index: int) -> bool:
	return level_index >= start_level_index and level_index <= end_level_index

func sanitize() -> void:
	start_level_index = maxi(start_level_index, 0)
	end_level_index = maxi(end_level_index, start_level_index)

