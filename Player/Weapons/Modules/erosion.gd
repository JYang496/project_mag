extends Module
# Use on hit-capable weapons to apply stacking erosion damage over time.
class_name Erosion

@export var base_tick: int = 5
@export var base_damage: int = 1
@export var tick_per_fuse: int = 0
@export var damage_per_fuse: int = 0

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
	if not target.has_method("apply_status_effect"):
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var level_scale := get_effective_additive(1.0, 0.4)
	var tick: int = max(1, int(round(float(base_tick + tick_per_fuse * fuse_bonus_steps) * level_scale)))
	var damage: int = max(1, int(round(float(base_damage + damage_per_fuse * fuse_bonus_steps) * level_scale)))
	var owner_player := DamageManager.resolve_source_player(source_weapon)
	var effect: ErosionStatusEffect = ErosionStatusEffect.new().setup_effect(tick, damage)
	effect.set_source_context(owner_player, source_weapon)
	target.apply_status_effect(effect)
