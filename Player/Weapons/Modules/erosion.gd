extends Module
class_name Erosion

@export var base_tick: int = 5
@export var base_damage: int = 1
@export var tick_per_fuse: int = 0
@export var damage_per_fuse: int = 0

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if target.get("status_list") == null:
		return

	var fuse_level: int = 1
	if source_weapon:
		fuse_level = max(1, int(source_weapon.fuse))
	var fuse_bonus_steps: int = max(0, fuse_level - 1)
	var tick: int = max(1, base_tick + tick_per_fuse * fuse_bonus_steps)
	var damage: int = max(1, base_damage + damage_per_fuse * fuse_bonus_steps)

	var erosion_obj: Dictionary = {"tick": tick, "damage": damage}
	var status_list: Dictionary = target.status_list
	if status_list.has("erosion"):
		var existing: Dictionary = status_list["erosion"]
		existing["tick"] = max(int(existing.get("tick", 0)), tick)
		existing["damage"] = max(int(existing.get("damage", 0)), damage)
		status_list["erosion"] = existing
	else:
		status_list["erosion"] = erosion_obj
