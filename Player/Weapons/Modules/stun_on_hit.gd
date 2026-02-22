extends Module

var ITEM_NAME := "Stun On Hit"

@export var base_chance: float = 0.25
@export var chance_per_fuse: float = 0.05
@export var base_stun_seconds: float = 0.5
@export var stun_seconds_per_fuse: float = 0.1

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if not target.has_method("apply_stun"):
		return

	var fuse_level := 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)

	var stun_chance: float = clampf(base_chance + chance_per_fuse * float(fuse_bonus_steps), 0.0, 1.0)
	if randf() > stun_chance:
		return

	var stun_seconds: float = maxf(0.0, base_stun_seconds + stun_seconds_per_fuse * float(fuse_bonus_steps))
	target.apply_stun(stun_seconds)
