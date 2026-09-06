extends HBoxContainer

@onready var grid: GridContainer = %Grid
@onready var inventory_title: Label = %InventoryTitle
@onready var status_label: Label = %Status
@onready var instruction_label: Label = %Instruction
@onready var detail_hint: Label = %DetailHint
@onready var battle_warning: Label = %BattleWarning
@onready var inventory_list: VBoxContainer = %InventoryList


func set_data(title: String, status: String, instruction: String, detail: String, warning: String) -> void:
	inventory_title.text = title
	status_label.text = status
	instruction_label.text = instruction
	detail_hint.text = detail
	detail_hint.visible = not detail.is_empty()
	battle_warning.text = warning
