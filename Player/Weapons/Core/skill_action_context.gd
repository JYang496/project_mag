extends RefCounted
class_name SkillActionContext

static var _next_action_id: int = 1

var action_id: int
var root_action_id: int
var source_skill: Node
var source_player: Node2D
var linked_weapon: Node
var skill_tags: Array[StringName] = []
var energy_spent: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var distance_travelled: float = 0.0
var trigger_depth: int = 0
var origin_module_id: StringName = StringName()
var is_triggered_action: bool = false
var proc_budget: int = 8

static func create(
	skill: Node,
	player: Node2D,
	weapon: Node,
	tags: Array[StringName],
	spent_energy: float
) -> SkillActionContext:
	var context := SkillActionContext.new()
	context.action_id = _next_action_id
	_next_action_id += 1
	context.root_action_id = context.action_id
	context.source_skill = skill
	context.source_player = player
	context.linked_weapon = weapon
	context.skill_tags = tags.duplicate()
	context.energy_spent = maxf(spent_energy, 0.0)
	context.start_position = player.global_position
	context.end_position = context.start_position
	return context

func has_tag(tag: StringName) -> bool:
	return skill_tags.has(tag)

func finish_at(position: Vector2) -> void:
	end_position = position
	distance_travelled = start_position.distance_to(end_position)

func create_triggered_child(module_id: StringName) -> SkillActionContext:
	var child := SkillActionContext.new()
	child.action_id = _next_action_id
	_next_action_id += 1
	child.root_action_id = root_action_id
	child.source_skill = source_skill
	child.source_player = source_player
	child.linked_weapon = linked_weapon
	child.skill_tags = skill_tags.duplicate()
	child.energy_spent = energy_spent
	child.start_position = start_position
	child.end_position = end_position
	child.distance_travelled = distance_travelled
	child.trigger_depth = trigger_depth + 1
	child.origin_module_id = module_id
	child.is_triggered_action = true
	child.proc_budget = maxi(proc_budget - 1, 0)
	return child
