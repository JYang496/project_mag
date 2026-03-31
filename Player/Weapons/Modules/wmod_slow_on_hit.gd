extends Module
# Use on hit-capable weapons to inflict a temporary slow status on enemies.

var ITEM_NAME := "Slow On Hit"

@export var chance: float = 1.0
@export var slow_multiplier: float = 0.7
@export var duration_seconds: float = 1.2
@export var chance_per_fuse: float = 0.0
@export var duration_per_fuse: float = 0.0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("apply_status_payload"):
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var final_chance: float = clampf(
		(chance + chance_per_fuse * float(fuse_bonus_steps)) * get_effective_additive(1.0, 0.3),
		0.0,
		1.0
	)
	if randf() > final_chance:
		return
	var final_duration: float = maxf(
		0.0,
		(duration_seconds + duration_per_fuse * float(fuse_bonus_steps)) * get_effective_additive(1.0, 0.35)
	)
	var final_slow_multiplier := clampf(
		1.0 - (1.0 - slow_multiplier) * get_effective_additive(1.0, 0.25),
		0.1,
		1.0
	)
	target.apply_status_payload(&"slow", {
		"multiplier": final_slow_multiplier,
		"duration": final_duration
	})
