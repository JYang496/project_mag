extends Node2D

@onready var module_parent : BulletBase = self.get_parent() # Bullet root is parent
@onready var detect_area: Area2D = $DetectArea

var linear_module : LinearMovement
var closest_target
# This module applies after bullet created
func _ready() -> void:
	module_parent = self.get_parent()
	if not module_parent:
		print("Error: module does not have owner")
		return
	for module in module_parent.module_list:
		if module is LinearMovement:
			linear_module = module


func _physics_process(delta: float) -> void:
	# get closest enemy each frame:
	var targets = detect_area.get_overlapping_areas()
	var closest_target = get_closest_area_optimized(targets, self)
	if closest_target:
		linear_module.direction = self.global_position.direction_to(closest_target.global_position)
		linear_module.speed = 10
		linear_module.adjust_base_displacement()


func get_closest_area_optimized(area_list: Array, target_node: Node2D) -> Area2D:
	if area_list.is_empty():
		return null
		
	var closest_area = area_list[0]
	var shortest_distance = closest_area.global_position.distance_squared_to(target_node.global_position)
	
	for area in area_list:
		if not area is Area2D:
			continue
			
		var distance = area.global_position.distance_squared_to(target_node.global_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_area = area
			
	return closest_area
