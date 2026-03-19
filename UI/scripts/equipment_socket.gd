extends TextureRect
class_name Socket

@onready var equipment_slot: EquipmentSlot = $"../../.."

@export var border_color: Color = Color(1, 1, 0)
@export var border_width: float = 4.0

var hover_over_color: Color = Color(1,1,0)
var hover_off_color: Color = Color(0,0,0,0)
var hover_over_width : float = 4.0
var hover_off_width : float = 0

var hover_over : bool = false
var module : Module :
	get():
		return module
	set(value):
		module = value
		if value:
			self.texture = module.sprite.texture
		else:
			self.texture = null

func _draw():
	# Get the size of the control
	var rect = Rect2(Vector2.ZERO, size)
	var width
	if hover_over:
		width = border_width
		border_color = hover_over_color
	else:
		width = hover_off_width
		border_color = hover_off_color
	if module:
		self.texture = module.sprite.texture
	else:
		self.texture = null
	draw_rect(rect, border_color, false, width)

func update() -> void:
	if module:
		self.texture = module.sprite.texture
	else:
		self.texture = null
	queue_redraw()

func _on_mouse_entered() -> void:
	hover_over = true
	update()


func _on_mouse_exited() -> void:
	hover_over = false
	update()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("CLICK") and equipment_slot is EquipmentSlotModule:
		if module == null:
			return
		var weapon := equipment_slot.item
		var result := InventoryData.unequip_module_from_weapon(module, weapon)
		if not result.get("ok", false):
			return
		var ui = GlobalVariables.ui
		if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
			ui.show_item_message("Removed %s from %s" % [
				module.get_module_display_name(),
				str(weapon.get("ITEM_NAME")) if weapon and weapon.get("ITEM_NAME") != null else "weapon"
			], 1.6)
