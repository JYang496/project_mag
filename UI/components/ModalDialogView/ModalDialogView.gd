extends ConfirmationDialog

@onready var content: VBoxContainer = %Content
@onready var title_bar: HBoxContainer = %TitleBar
@onready var title_label: Label = %Title
@onready var close_button: Button = %CloseButton
@onready var accent_bar: ColorRect = %AccentBar
@onready var body_scroll: ScrollContainer = %BodyScroll
@onready var body_content: VBoxContainer = %BodyContent
@onready var message_panel: PanelContainer = %MessagePanel
@onready var message_label: Label = %Message
@onready var details_container: VBoxContainer = %Details
@onready var checkbox_panel: PanelContainer = %CheckboxPanel
@onready var checkbox: CheckBox = %OptionalCheckbox


func fit_content_to_native_message() -> void:
	var native_message := get_label()
	if native_message == null:
		return
	content.position = native_message.position
	content.size = native_message.size
