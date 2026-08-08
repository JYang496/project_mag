extends Resource
class_name RunProgressionProfile

const RUN_CHAPTER_DEFINITION := preload("res://data/progression/RunChapterDefinition.gd")

const SETTLEMENT_QUICK := &"quick"
const SETTLEMENT_CHAPTER := &"chapter"
const SETTLEMENT_FINAL := &"final"

@export var chapters: Array[Resource] = []
@export var final_level_index: int = 9
@export var fixed_contract_level_count: int = 2
@export var fixed_early_contract_id: StringName = &"elimination"
@export var final_contract_id: StringName = &"finale"

func sanitize() -> void:
	final_level_index = maxi(final_level_index, 0)
	fixed_contract_level_count = clampi(fixed_contract_level_count, 0, final_level_index + 1)
	for chapter in chapters:
		if chapter != null:
			chapter.sanitize()
	chapters.sort_custom(func(a: Resource, b: Resource) -> bool:
		return a.start_level_index < b.start_level_index
	)

func get_chapter_for_level(level_index: int) -> Resource:
	for chapter in chapters:
		if chapter != null and chapter.contains_level(level_index):
			return chapter
	return null

func is_chapter_start(level_index: int) -> bool:
	var chapter: Resource = get_chapter_for_level(level_index)
	return chapter != null and chapter.start_level_index == level_index

func is_chapter_end(level_index: int) -> bool:
	var chapter: Resource = get_chapter_for_level(level_index)
	return chapter != null and chapter.end_level_index == level_index

func is_final_level(level_index: int) -> bool:
	return level_index == final_level_index

func get_settlement_type_for_completed_level(level_index: int) -> StringName:
	if is_final_level(level_index):
		return SETTLEMENT_FINAL
	if is_chapter_end(level_index):
		return SETTLEMENT_CHAPTER
	return SETTLEMENT_QUICK

func get_active_cell_ids_for_level(level_index: int) -> PackedInt32Array:
	var chapter: Resource = get_chapter_for_level(level_index)
	if chapter != null and not chapter.board_active_cell_ids.is_empty():
		return chapter.board_active_cell_ids.duplicate()
	if not chapters.is_empty():
		var last := chapters.back() as Resource
		if last != null:
			return last.board_active_cell_ids.duplicate()
	return PackedInt32Array([5, 6])
