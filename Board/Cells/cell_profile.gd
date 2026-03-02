extends Resource
class_name CellProfile

@export_enum("NONE:0", "OFFENSE:1", "DEFENSE:2")
var task_type: int = Cell.TaskType.NONE
@export_enum("NONE:0", "COMBAT:1", "ECONOMY:2")
var reward_type: int = Cell.RewardType.NONE
@export_enum("NONE:0", "CORROSION:1", "JUNGLE:2", "SPEED_BOOST:3", "REGEN:4", "LUCKY_STRIKE:5", "DOUBLE_LOOT:6", "LOW_HP_BERSERK:7")
var terrain_type: int = Cell.TerrainType.NONE
@export var objective_enabled := false
@export var aura_enabled := false

# ========== Task Parameters ==========
@export_group("Task Parameters")

@export_subgroup("Offense (Kill) Task")
@export var offense_required_kill_count: int = 10
@export var offense_count_kill_only_when_player_inside := true

@export_subgroup("Defense (Hold) Task")
@export var defense_required_hold_seconds: float = 8.0
@export var defense_required_progress: int = 50

# ========== Bonus Parameters ==========
@export_group("Bonus Parameters")

@export_subgroup("Combat Bonus")
@export var combat_heal_hp: int = 1
@export var combat_bonus_speed: float = 20.0
@export var combat_bonus_duration: float = 10.0
@export var combat_bonus_armor: int = 0
@export var combat_bonus_crit_rate: float = 0.0
@export var combat_bonus_crit_damage: float = 0.0
@export var combat_bonus_shield: int = 0
@export var combat_bonus_damage_reduction: float = 1.0

@export_subgroup("Economy Bonus")
@export var economy_gold: int = 20
@export var economy_exp: int = 0
@export var economy_drop_coin: int = 0
@export var economy_drop_chip: int = 0
@export var economy_drop_coin_value: int = 1
@export var economy_drop_chip_value: int = 1

# ========== Aura Parameters ==========
@export_group("Aura Parameters")
@export_subgroup("Corrosion Aura")
@export var aura_corrosion_move_speed_mul: float = 0.7

@export_subgroup("Jungle Aura")
@export var aura_jungle_vision_mul: float = 0.7

@export_subgroup("Speed Aura")
@export var aura_speed_move_speed_mul: float = 1.2

@export_subgroup("Regen Aura")
@export var aura_regen_interval_sec: float = 5.0
@export var aura_regen_heal_amount: int = 1

@export_subgroup("Lucky Strike Aura")
@export var aura_lucky_strike_chance: float = 0.3
@export var aura_lucky_strike_extra_damage: int = 1

@export_subgroup("Double Loot Aura")
@export var aura_double_loot_coin_chance: float = 0.3
@export var aura_double_loot_chip_chance: float = 0.3
@export var aura_double_loot_multiplier: int = 2

@export_subgroup("Low HP Berserk Aura")
@export var aura_low_hp_min_hp_ratio: float = 0.25
@export var aura_low_hp_max_damage_mul: float = 1.5

@export_group("Auto Mapping")
@export var use_auto_module_mapping := true
@export var use_manual_module_scenes := false

@export_group("Manual Modules")
@export var module_scenes: Array[PackedScene] = []

const TASK_OBJECTIVE_REGISTRY := {
	Cell.TaskType.OFFENSE: "res://Board/Cells/Modules/offense_kill_objective_module.tscn",
	Cell.TaskType.DEFENSE: "res://Board/Cells/Modules/defense_hold_objective_module.tscn"
}
const TERRAIN_AURA_REGISTRY := {
	Cell.TerrainType.CORROSION: "res://Board/Cells/Modules/corrosion_aura_module.tscn",
	Cell.TerrainType.JUNGLE: "res://Board/Cells/Modules/jungle_aura_module.tscn",
	Cell.TerrainType.SPEED_BOOST: "res://Board/Cells/Modules/speed_boost_aura_module.tscn",
	Cell.TerrainType.REGEN: "res://Board/Cells/Modules/regen_aura_module.tscn",
	Cell.TerrainType.LUCKY_STRIKE: "res://Board/Cells/Modules/lucky_strike_aura_module.tscn",
	Cell.TerrainType.DOUBLE_LOOT: "res://Board/Cells/Modules/double_loot_aura_module.tscn",
	Cell.TerrainType.LOW_HP_BERSERK: "res://Board/Cells/Modules/low_hp_berserk_aura_module.tscn"
}
static var _SCENE_CACHE: Dictionary = {}

func resolve_module_scenes() -> Array[PackedScene]:
	var resolved: Array[PackedScene] = []
	if use_auto_module_mapping:
		if objective_enabled:
			_append_from_registry(resolved, TASK_OBJECTIVE_REGISTRY, task_type)
		if aura_enabled:
			_append_from_registry(resolved, TERRAIN_AURA_REGISTRY, terrain_type)
	if use_manual_module_scenes:
		for scene in module_scenes:
			if scene:
				resolved.append(scene)
	return _dedupe_module_scenes(resolved)

func _append_from_registry(output: Array[PackedScene], registry: Dictionary, enum_value: int) -> void:
	if not registry.has(enum_value):
		return
	var scene_path := str(registry[enum_value])
	var scene := _load_scene_cached(scene_path)
	if scene:
		output.append(scene)

func _load_scene_cached(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _SCENE_CACHE.has(scene_path):
		return _SCENE_CACHE[scene_path] as PackedScene
	var loaded = load(scene_path)
	if loaded is PackedScene:
		_SCENE_CACHE[scene_path] = loaded
		return loaded as PackedScene
	return null

func _dedupe_module_scenes(scenes: Array[PackedScene]) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var seen: Dictionary = {}
	for scene in scenes:
		if scene == null:
			continue
		var key := scene.resource_path
		if key == "":
			key = str(scene.get_instance_id())
		if seen.has(key):
			continue
		seen[key] = true
		result.append(scene)
	return result
