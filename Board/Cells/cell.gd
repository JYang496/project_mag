extends Node2D

# Body with layer 5 can be detected
func _on_area_2d_body_entered(body: Node2D) -> void:
	prints(self,"Body enter",body)


func _on_area_2d_body_exited(body: Node2D) -> void:
	prints(self,"Body exit",body)
