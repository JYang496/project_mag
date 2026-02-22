extends Module

var ITEM_NAME := "Lightning Chain"

@export var chain_count: int = 2
@export var chain_range: float = 140.0
@export var chain_damage_ratio: float = 0.4
@export var chain_count_per_fuse: int = 0
@export var line_width: float = 2.0
@export var line_duration: float = 0.12

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	var target2d: Node2D = target as Node2D
	if target2d == null:
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var bounce_count: int = max(0, chain_count + chain_count_per_fuse * fuse_bonus_steps)
	if bounce_count <= 0:
		return

	var base_damage: int = 1
	if source_weapon and source_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon.damage))
	var chain_damage: int = max(1, int(round(float(base_damage) * chain_damage_ratio)))

	var candidates: Array[Node] = []
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_ref as Node2D
		if enemy == null or enemy == target:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(target2d.global_position) <= chain_range:
			candidates.append(enemy)

	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		var a2d: Node2D = a as Node2D
		var b2d: Node2D = b as Node2D
		var target_pos := target2d.global_position
		return a2d.global_position.distance_to(target_pos) < b2d.global_position.distance_to(target_pos)
	)

	for i in range(min(bounce_count, candidates.size())):
		var chained_target: Node = candidates[i]
		if chained_target and chained_target.has_method("damaged"):
			var atk := Attack.new()
			atk.damage = chain_damage
			_draw_chain_line(target2d.global_position, (chained_target as Node2D).global_position)
			chained_target.damaged(atk)

func _draw_chain_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var line: Line2D = Line2D.new()
	line.top_level = true
	line.global_position = Vector2.ZERO
	line.default_color = Color.WHITE
	line.width = line_width
	line.z_index = 200
	line.points = PackedVector2Array([from_pos, to_pos])

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(line)

	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, line_duration)
	tween.finished.connect(func() -> void:
		if is_instance_valid(line):
			line.queue_free()
	)
