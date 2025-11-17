extends BaseNPC
class_name FriendlyNPC


var player_in_zone : bool = false
var is_interacting : bool = false


func _ready():
	pass

func _on_shopping_area_body_entered(body):
	if body is Player:
		$InteractHint.visible = true
		player_in_zone = true


func _on_shopping_area_body_exited(body):
	if body is Player:
		panel_move_out()
		$InteractHint.visible = false
		player_in_zone = false
		PlayerData.is_interacting = false

func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("INTERACT") and player_in_zone:
		if not PlayerData.is_interacting:
			PlayerData.is_interacting = true
			panel_move_in()
		else:
			panel_move_out()
			PlayerData.is_interacting = false

func panel_move_in() -> void:
	PlayerData.is_interacting = true
		
func panel_move_out() -> void:
	PlayerData.is_interacting = false
	
