class_name HybridGroundShadow2D
extends Node2D

func _ready() -> void:
	if is_inside_tree() and not get_tree().get_nodes_in_group(&"hybrid_ground_view_3d").is_empty():
		visible = false
	call_deferred("_register_with_hybrid_ground")

func _register_with_hybrid_ground() -> void:
	if not is_inside_tree():
		return
	if HybridGroundRegistration.register(self, &"register_shadow"):
		visible = false

func _exit_tree() -> void:
	HybridGroundRegistration.unregister(self)
