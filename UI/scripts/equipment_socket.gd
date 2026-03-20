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
		var selected_module: Module = module
		if selected_module == null or not is_instance_valid(selected_module):
			return
		var weapon: Weapon = equipment_slot.item
		var module_display_name: String = selected_module.get_module_display_name()
		var weapon_display_name: String = str(weapon.get("ITEM_NAME")) if weapon and weapon.get("ITEM_NAME") != null else "weapon"
		var result := InventoryData.unequip_module_from_weapon(selected_module, weapon)
		if not result.get("ok", false):
			return
		var ui = GlobalVariables.ui
		if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
			ui.show_item_message("Removed %s from %s" % [
				module_display_name,
				weapon_display_name
			], 1.6)
