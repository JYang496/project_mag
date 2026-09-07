extends HBoxContainer

const DETAIL_TEXT_SCENE := preload("res://UI/components/DetailText/DetailText.tscn")

@onready var prefix_label: Label = %FusionRecipePrefix
@onready var conditions: VBoxContainer = %FusionRecipeConditions


func set_data(prefix: String, tags: Array) -> void:
	if prefix_label == null:
		prefix_label = get_node("FusionRecipePrefix") as Label
		conditions = get_node("FusionRecipeConditions") as VBoxContainer
	prefix_label.text = prefix
	for child in conditions.get_children():
		child.queue_free()
	for tag_variant in tags:
		var tag := tag_variant as Dictionary
		var label := DETAIL_TEXT_SCENE.instantiate() as Label
		label.name = "FusionRecipeTag%s" % str(tag.get("id", "")).to_pascal_case()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.set_meta(&"satisfied", bool(tag.get("satisfied", false)))
		label.call("set_data", str(tag.get("text", "")), tag.get("color", Color.WHITE) as Color, 11)
		conditions.add_child(label)
