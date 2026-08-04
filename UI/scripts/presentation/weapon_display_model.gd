extends RefCounted
class_name WeaponDisplayModel

var weapon_id: String = ""
var display_name: String = ""
var base_name: String = ""
var description: String = ""
var icon: Texture2D
var rarity: String = "common"
var price: int = 0

var level: int = 1
var max_level: int = 1
var fuse: int = 1
var location: String = ""
var module_count: int = 0
var module_capacity: int = 0

var traits := PackedStringArray()
var delivery_types := PackedStringArray()
var capabilities := PackedStringArray()
var taxonomy_labels := PackedStringArray()
var selected_branches: Array[Dictionary] = []
var available_branches: Array[Dictionary] = []

var current_stats: Dictionary = {}
var next_stats: Dictionary = {}
var upgrade_deltas: Array[Dictionary] = []


func taxonomy_text() -> String:
	return " / ".join(taxonomy_labels) if not taxonomy_labels.is_empty() else LocalizationManager.tr_key("ui.service.value.universal", "Universal")


func first_description_sentence() -> String:
	var clean := description.strip_edges().replace("\n", " ")
	if clean == "":
		return ""
	var end := clean.find(".")
	var chinese_end := clean.find("。")
	if chinese_end >= 0 and (end < 0 or chinese_end < end):
		end = chinese_end
	return clean.substr(0, end + 1) if end >= 0 else clean
