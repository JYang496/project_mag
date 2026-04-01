extends Module
# Spawns freeze damage field when killing frosted enemies.

const FROST_FIELD_EFFECT_SCENE: PackedScene = preload("res://Player/Weapons/Effects/frost_field_effect.tscn")

var ITEM_NAME := "Permafrost Field"

@export var duration_sec: float = 2.5
@export var radius: float = 140.0
@export var tick_sec: float = 0.5
@export var tick_damage_lv1: int = 2
@export var tick_damage_lv2: int = 3
@export var tick_damage_lv3: int = 4
@export var max_fields: int = 3

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	if not target.has_meta("_incoming_damage_state"):
		return
	var state_variant: Variant = target.get_meta("_incoming_damage_state", {})
	if not (state_variant is Dictionary):
		return
	var state: Dictionary = state_variant
	var frost_stacks: int = int(state.get("frost_stacks", 0))
	if frost_stacks <= 0:
		return
	var is_dead: bool = false
	if target.get("is_dead") != null:
		is_dead = bool(target.get("is_dead"))
	elif target.get("hp") != null:
		is_dead = int(target.get("hp")) <= 0
	if not is_dead:
		return
	_spawn_permafrost_field(source_weapon, target as Node2D)

func _spawn_permafrost_field(source_weapon: Weapon, target: Node2D) -> void:
	var field: Node2D = FROST_FIELD_EFFECT_SCENE.instantiate() as Node2D
	if field == null:
		return
	if field.has_method("setup"):
		field.call(
			"setup",
			source_weapon,
			DamageManager.resolve_source_player(source_weapon),
			Attack.TYPE_FREEZE,
			_get_tick_damage_by_level(),
			maxf(tick_sec, 0.05),
			maxf(duration_sec, 0.1),
			maxf(radius, 8.0),
			false,
			max(1, max_fields)
		)
	field.global_position = target.global_position
	var tree: SceneTree = null
	if target != null and is_instance_valid(target):
		tree = target.get_tree()
	if tree == null and source_weapon != null and is_instance_valid(source_weapon):
		tree = source_weapon.get_tree()
	if tree == null:
		tree = get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	if parent == null:
		return
	parent.add_child(field)

func _get_tick_damage_by_level() -> int:
	match module_level:
		3:
			return max(1, tick_damage_lv3)
		2:
			return max(1, tick_damage_lv2)
		_:
			return max(1, tick_damage_lv1)
