extends VBoxContainer

@onready var heading: Label = %Heading
@onready var branch_row: HBoxContainer = %BranchPreviewRow


func set_heading(value: String) -> void:
	if heading == null:
		heading = get_node("HeadingRow/Heading") as Label
	heading.text = value


func get_branch_container() -> HBoxContainer:
	if branch_row == null:
		branch_row = get_node("BranchPreviewRow") as HBoxContainer
	return branch_row
