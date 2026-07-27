extends RefCounted
class_name HitLabelCrowding

const GROUP := &"active_hit_labels"
const RADIUS := 42.0
const VERTICAL_STEP := 22.0
const MAX_LEVEL := 4

static func resolve(label: Control, motion) -> void:
	if not label.is_inside_tree():
		return
	var occupied_level := 0
	var center := label.position + label.size * 0.5
	for item in label.get_tree().get_nodes_in_group(GROUP):
		var other := item as Control
		if other == null or not is_instance_valid(other):
			continue
		var other_center := other.position + other.size * 0.5
		if other_center.distance_to(center) <= RADIUS:
			occupied_level += 1
	label.position.y -= float(mini(occupied_level, MAX_LEVEL)) * VERTICAL_STEP
	label.position = motion.clamp_to_viewport(label, label.position.round())
