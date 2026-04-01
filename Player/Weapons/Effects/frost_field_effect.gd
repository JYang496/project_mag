extends Node2D
class_name FrostFieldEffect

var source_node: Node
var source_player: Node
var damage_type: StringName = Attack.TYPE_FREEZE
var tick_damage: int = 1
var tick_interval_sec: float = 0.5
var duration_sec: float = 2.5
var radius: float = 140.0
var affect_players: bool = false
var max_instances_per_owner: int = 3

var _elapsed_sec: float = 0.0
var _tick_accum_sec: float = 0.0

func setup(
	source_node_value: Node,
	source_player_value: Node,
	damage_type_value: StringName,
	tick_damage_value: int,
	tick_interval_value: float,
	duration_value: float,
	radius_value: float,
	affect_players_value: bool = false,
	max_instances_value: int = 3
) -> FrostFieldEffect:
	source_node = source_node_value
	source_player = source_player_value
	damage_type = Attack.normalize_damage_type(damage_type_value)
	tick_damage = max(1, tick_damage_value)
	tick_interval_sec = maxf(0.05, tick_interval_value)
	duration_sec = maxf(0.1, duration_value)
	radius = maxf(8.0, radius_value)
	affect_players = affect_players_value
	max_instances_per_owner = max(1, max_instances_value)
	return self

func _ready() -> void:
	_enforce_instance_cap()

func _process(delta: float) -> void:
	_elapsed_sec += maxf(delta, 0.0)
	if _elapsed_sec >= duration_sec:
		queue_free()
		return
	_tick_accum_sec += maxf(delta, 0.0)
	while _tick_accum_sec >= tick_interval_sec:
		_tick_accum_sec -= tick_interval_sec
		_apply_tick_damage()

func _apply_tick_damage() -> void:
	var candidates: Array[Node] = []
	if affect_players:
		var player: Node = PlayerData.player
		if player and is_instance_valid(player):
			candidates.append(player)
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node = enemy_ref as Node
		if enemy and is_instance_valid(enemy):
			candidates.append(enemy)
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		if (candidate as Node2D).global_position.distance_to(global_position) > radius:
			continue
		var damage_data: DamageData = DamageData.new().setup(
			tick_damage,
			damage_type,
			{"amount": 0, "angle": Vector2.ZERO},
			source_node,
			source_player
		)
		DamageManager.apply_to_target(candidate, damage_data)

func _enforce_instance_cap() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var same_owner_fields: Array[FrostFieldEffect] = []
	for child in parent.get_children():
		var field: FrostFieldEffect = child as FrostFieldEffect
		if field == null:
			continue
		if field.source_node == source_node:
			same_owner_fields.append(field)
	if same_owner_fields.size() <= max_instances_per_owner:
		return
	same_owner_fields.sort_custom(func(a: FrostFieldEffect, b: FrostFieldEffect) -> bool:
		return a.get_instance_id() < b.get_instance_id()
	)
	while same_owner_fields.size() > max_instances_per_owner:
		var oldest: FrostFieldEffect = same_owner_fields[0]
		same_owner_fields.remove_at(0)
		if oldest != null and is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()
