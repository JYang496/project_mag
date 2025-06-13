extends Effect
class_name ChaseEnemy

@onready var detect_area: Area2D = $DetectArea

var linear_module : LinearMovement
var closest_target

func bullet_effect_ready() -> void:
	for effect in bullet.effect_list:
		if effect is LinearMovement:
			linear_module = effect

func _physics_process(delta: float) -> void:
	# get closest enemy each frame:
	var targets = detect_area.get_overlapping_areas()
	var closest_target = get_closest_area_optimized(targets, self)
	if closest_target and linear_module:
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
