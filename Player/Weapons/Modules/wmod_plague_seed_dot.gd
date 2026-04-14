extends Module
# Applies plague seed DOT. Seeded enemies spread DOT to nearby enemies when they die.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Plague Seed"

@export var dot_ticks_lv1: int = 3
@export var dot_ticks_lv2: int = 4
@export var dot_ticks_lv3: int = 5
@export var dot_damage_lv1: int = 1
@export var dot_damage_lv2: int = 2
@export var dot_damage_lv3: int = 3
@export var spread_radius: float = 170.0

var _seeded_targets: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_clear_seed_connections()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	_apply_plague_dot(target, source_weapon)
	_track_seed_target(target, source_weapon)
	if _is_target_dead(target):
		_spread_from_target(target, source_weapon)
		_untrack_seed_target(target.get_instance_id(), target)

func _apply_plague_dot(target: Node, source_weapon: Weapon) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_status_effect"):
		return
	var ticks: int = _get_dot_ticks()
	var damage: int = _get_dot_damage()
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var effect := DotStatusEffect.new().setup_dot_effect(ticks, damage, Attack.TYPE_PHYSICAL)
	effect.set_source_context(owner_player, source_weapon)
	target.call("apply_status_effect", effect)

func _track_seed_target(target: Node, source_weapon: Weapon) -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_id: int = target.get_instance_id()
	if not _seeded_targets.has(target_id):
		_seeded_targets[target_id] = {
			"target_ref": weakref(target),
			"source_weapon_ref": weakref(source_weapon) if source_weapon != null else null,
		}
	if target.has_signal("enemy_death"):
		var callback := Callable(self, "_on_seeded_enemy_death").bind(target_id)
		if not target.is_connected("enemy_death", callback):
			target.connect("enemy_death", callback)

func _untrack_seed_target(target_id: int, target: Node = null) -> void:
	if target != null and is_instance_valid(target) and target.has_signal("enemy_death"):
		var callback := Callable(self, "_on_seeded_enemy_death").bind(target_id)
		if target.is_connected("enemy_death", callback):
			target.disconnect("enemy_death", callback)
	_seeded_targets.erase(target_id)

func _on_seeded_enemy_death(_was_killed: bool, target_id: int) -> void:
	var entry_variant: Variant = _seeded_targets.get(target_id, null)
	if not (entry_variant is Dictionary):
		return
	var entry: Dictionary = entry_variant
	var target_ref: WeakRef = entry.get("target_ref", null)
	var target: Node = target_ref.get_ref() as Node if target_ref != null else null
	var source_weapon_ref: WeakRef = entry.get("source_weapon_ref", null)
	var source_weapon: Weapon = source_weapon_ref.get_ref() as Weapon if source_weapon_ref != null else null
	_spread_from_target(target, source_weapon)
	_untrack_seed_target(target_id, target)

func _spread_from_target(seed_target: Node, source_weapon: Weapon) -> void:
	if seed_target == null or not is_instance_valid(seed_target):
		return
	if not (seed_target is Node2D):
		return
	var seed_target2d := seed_target as Node2D
	var tree := seed_target2d.get_tree()
	if tree == null:
		return
	var nearby := UTILS.get_nearby_enemies(tree, seed_target2d.global_position, maxf(spread_radius, 8.0))
	for enemy in nearby:
		if enemy == null or not is_instance_valid(enemy) or enemy == seed_target:
			continue
		_apply_plague_dot(enemy, source_weapon)

func _is_target_dead(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.get("is_dead") != null:
		return bool(target.get("is_dead"))
	if target.get("hp") != null:
		return int(target.get("hp")) <= 0
	return false

func _clear_seed_connections() -> void:
	for target_id_variant in _seeded_targets.keys():
		var target_id: int = int(target_id_variant)
		var entry_variant: Variant = _seeded_targets[target_id]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var target_ref: WeakRef = entry.get("target_ref", null)
		var target: Node = target_ref.get_ref() as Node if target_ref != null else null
		_untrack_seed_target(target_id, target)
	_seeded_targets.clear()

func _get_dot_ticks() -> int:
	match module_level:
		3:
			return max(1, dot_ticks_lv3)
		2:
			return max(1, dot_ticks_lv2)
		_:
			return max(1, dot_ticks_lv1)

func _get_dot_damage() -> int:
	match module_level:
		3:
			return max(1, dot_damage_lv3)
		2:
			return max(1, dot_damage_lv2)
		_:
			return max(1, dot_damage_lv1)
