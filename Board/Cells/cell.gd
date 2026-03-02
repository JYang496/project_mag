extends Node2D
class_name Cell

signal cell_state_changed(cell: Cell, old_state: int, new_state: int)
signal effect_triggered(cell: Cell, effect: Node, actor: Node)
signal player_presence_changed(cell: Cell, player_count: int)
signal enemy_presence_changed(cell: Cell, enemy_count: int)
signal enemy_killed_in_cell(cell: Cell, enemy: BaseEnemy)
signal objective_completed(cell_id: String)

enum CellState {IDLE, PLAYER, CONTESTED, LOCKED}
enum TaskType {NONE, OFFENSE, DEFENSE}
enum RewardType {NONE, COMBAT, ECONOMY}
enum TerrainType {NONE, CORROSION, JUNGLE, SPEED_BOOST, REGEN, LUCKY_STRIKE, DOUBLE_LOOT, LOW_HP_BERSERK}

var state: int = CellState.LOCKED : set = set_state
var _player_bodies: Array[Node2D] = []
var _enemy_bodies: Array[Node2D] = []
var _enemy_death_callbacks: Dictionary = {}
var progress: int = 0
@onready var _sprite: Sprite2D = $Texture/Sprite2D
var _default_color: Color = Color.WHITE
var _is_highlighted := false
var _pending_highlight_color: Color = Color.WHITE
var _has_pending_highlight := false
@export var task_type: int = TaskType.NONE
@export var reward_type: int = RewardType.NONE
@export var terrain_type: int = TerrainType.NONE
@export var objective_enabled := false
@export var aura_enabled := false
@export var profile: CellProfile
@export var module_scenes: Array[PackedScene] = []

const PROGRESS_INTERVAL := 0.2
const PROGRESS_STEP := 1
const PROGRESS_LIMIT := 100
const CONTESTED_PROGRESS_MULTIPLIER := 0.5
const TERRAIN_TEXTURE_PATHS := {
	TerrainType.JUNGLE: "res://asset/images/cells/glass.png",
	TerrainType.SPEED_BOOST: "res://asset/images/cells/ice.png",
	TerrainType.LOW_HP_BERSERK: "res://asset/images/cells/lava.png"
}

var _progress_timer: Timer
var _module_root: Node
var _progress_accumulator := 0.0

func set_state(value: int) -> void:
	if state == value:
		return
	var old = state
	state = value
	cell_state_changed.emit(self, old, state)
	_update_visual_by_state()

func _ready() -> void:
	if _sprite:
		_default_color = _sprite.modulate
		_apply_terrain_texture()
	if _is_highlighted and _has_pending_highlight and _sprite:
		_sprite.modulate = _pending_highlight_color
		_has_pending_highlight = false
	_progress_timer = Timer.new()
	_progress_timer.wait_time = PROGRESS_INTERVAL
	_progress_timer.autostart = true
	_progress_timer.one_shot = false
	add_child(_progress_timer)
	_progress_timer.timeout.connect(_on_progress_timer_timeout)
	_setup_profile_and_modules()

func _update_visual_by_state() -> void:
	pass

func _update_visual_color() -> void:
	if not _sprite or _is_highlighted:
		return
	_sprite.modulate = _default_color

func set_highlight_color(color: Color) -> void:
	_is_highlighted = true
	if not _sprite:
		_pending_highlight_color = color
		_has_pending_highlight = true
		return
	_has_pending_highlight = false
	_sprite.modulate = color

func clear_highlight() -> void:
	if not _sprite:
		_is_highlighted = false
		_has_pending_highlight = false
		return
	_is_highlighted = false
	_update_visual_color()

func apply_profile(new_profile: CellProfile) -> void:
	profile = new_profile
	if profile == null:
		return
	task_type = profile.task_type
	reward_type = profile.reward_type
	terrain_type = profile.terrain_type
	_apply_terrain_texture()
	objective_enabled = profile.objective_enabled
	aura_enabled = profile.aura_enabled
	module_scenes = profile.resolve_module_scenes()

func _apply_terrain_texture() -> void:
	if not _sprite:
		return
	if not TERRAIN_TEXTURE_PATHS.has(terrain_type):
		return
	var texture_path := str(TERRAIN_TEXTURE_PATHS[terrain_type])
	var loaded := load(texture_path)
	if loaded is Texture2D:
		_sprite.texture = loaded

func set_locked(is_locked: bool) -> void:
	if is_locked:
		set_state(CellState.LOCKED)
		_progress_accumulator = 0.0
	else:
		# Leave LOCKED first, then evaluate occupancy to derive PLAYER/CONTESTED/IDLE.
		if state == CellState.LOCKED:
			set_state(CellState.IDLE)
		_evaluate_cell_state()

func has_player_inside() -> bool:
	return not _player_bodies.is_empty()

func has_enemy_inside() -> bool:
	return not _enemy_bodies.is_empty()

func get_player_count() -> int:
	return _player_bodies.size()

func get_enemy_count() -> int:
	return _enemy_bodies.size()

func emit_objective_completed() -> void:
	objective_completed.emit(name)

func _evaluate_cell_state() -> void:
	if state == CellState.LOCKED:
		return
	var player_present := not _player_bodies.is_empty()
	var enemy_present := not _enemy_bodies.is_empty()
	if player_present and enemy_present:
		set_state(CellState.CONTESTED)
	elif player_present:
		set_state(CellState.PLAYER)
	else:
		set_state(CellState.IDLE)

func _on_progress_timer_timeout() -> void:
	if state == CellState.LOCKED:
		return
	var delta := 0.0
	if state == CellState.PLAYER:
		delta = PROGRESS_STEP
	elif state == CellState.CONTESTED:
		delta = PROGRESS_STEP * CONTESTED_PROGRESS_MULTIPLIER
	if delta == 0:
		return
	_progress_accumulator += delta
	var progress_step := int(floor(_progress_accumulator))
	if progress_step <= 0:
		return
	_progress_accumulator -= progress_step
	progress = clamp(progress + progress_step, 0, PROGRESS_LIMIT)

# Body with layer 5 can be detected
func _on_area_2d_body_entered(body: Node2D) -> void:
	var state_changed := false
	if body is Player and not _player_bodies.has(body):
		_player_bodies.append(body)
		player_presence_changed.emit(self, _player_bodies.size())
		state_changed = true
	elif body is BaseEnemy and not _enemy_bodies.has(body):
		_enemy_bodies.append(body)
		_track_enemy_death(body)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		state_changed = true
	if state_changed:
		_evaluate_cell_state()


func _on_area_2d_body_exited(body: Node2D) -> void:
	var state_changed := false
	if body is Player and _player_bodies.has(body):
		_player_bodies.erase(body)
		player_presence_changed.emit(self, _player_bodies.size())
		state_changed = true
	elif body is BaseEnemy and _enemy_bodies.has(body):
		_enemy_bodies.erase(body)
		_untrack_enemy_death(body)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		state_changed = true
	if state_changed:
		_evaluate_cell_state()

func _track_enemy_death(enemy: BaseEnemy) -> void:
	if enemy == null or _enemy_death_callbacks.has(enemy):
		return
	var callback := Callable(self, "_on_tracked_enemy_death").bind(enemy)
	_enemy_death_callbacks[enemy] = callback
	if not enemy.is_connected("enemy_death", callback):
		enemy.connect("enemy_death", callback)

func _untrack_enemy_death(enemy: BaseEnemy) -> void:
	if enemy == null:
		return
	if not _enemy_death_callbacks.has(enemy):
		return
	var callback: Callable = _enemy_death_callbacks[enemy]
	if is_instance_valid(enemy) and enemy.is_connected("enemy_death", callback):
		enemy.disconnect("enemy_death", callback)
	_enemy_death_callbacks.erase(enemy)

func _on_tracked_enemy_death(enemy: BaseEnemy) -> void:
	var was_inside := _enemy_bodies.has(enemy)
	if was_inside:
		_enemy_bodies.erase(enemy)
		enemy_presence_changed.emit(self, _enemy_bodies.size())
		enemy_killed_in_cell.emit(self, enemy)
	_evaluate_cell_state()
	_untrack_enemy_death(enemy)

func _setup_profile_and_modules() -> void:
	if profile:
		apply_profile(profile)
	_module_root = get_node_or_null("Modules")
	if _module_root == null:
		_module_root = Node.new()
		_module_root.name = "Modules"
		add_child(_module_root)
	if module_scenes.is_empty():
		return
	for module_scene in module_scenes:
		if module_scene == null:
			continue
		var module_instance = module_scene.instantiate()
		if module_instance:
			_module_root.add_child(module_instance)
			_apply_module_parameters(module_instance)

func _apply_module_parameters(module_instance: Node) -> void:
	if profile == null:
		return
	# Apply task parameters
	if module_instance.has_method("set_task_parameters"):
		match task_type:
			Cell.TaskType.OFFENSE:
				module_instance.set_task_parameters({
					"required_kill_count": profile.offense_required_kill_count,
					"count_kill_only_when_player_inside": profile.offense_count_kill_only_when_player_inside
				})
			Cell.TaskType.DEFENSE:
				module_instance.set_task_parameters({
					"required_hold_seconds": profile.defense_required_hold_seconds,
					"required_progress": profile.defense_required_progress
				})
	# Apply bonus parameters
	if module_instance.has_method("set_bonus_parameters"):
		module_instance.set_bonus_parameters({
			"combat_heal_hp": profile.combat_heal_hp,
			"combat_bonus_speed": profile.combat_bonus_speed,
			"combat_bonus_duration": profile.combat_bonus_duration,
			"combat_bonus_armor": profile.combat_bonus_armor,
			"combat_bonus_crit_rate": profile.combat_bonus_crit_rate,
			"combat_bonus_crit_damage": profile.combat_bonus_crit_damage,
			"combat_bonus_shield": profile.combat_bonus_shield,
			"combat_bonus_damage_reduction": profile.combat_bonus_damage_reduction,
			"economy_gold": profile.economy_gold,
			"economy_exp": profile.economy_exp,
			"economy_drop_coin": profile.economy_drop_coin,
			"economy_drop_chip": profile.economy_drop_chip,
			"economy_drop_coin_value": profile.economy_drop_coin_value,
			"economy_drop_chip_value": profile.economy_drop_chip_value
		})
	# Apply aura parameters
	if module_instance.has_method("set_aura_parameters"):
		module_instance.set_aura_parameters({
			"aura_corrosion_move_speed_mul": profile.aura_corrosion_move_speed_mul,
			"aura_jungle_vision_mul": profile.aura_jungle_vision_mul,
			"aura_speed_move_speed_mul": profile.aura_speed_move_speed_mul,
			"aura_regen_interval_sec": profile.aura_regen_interval_sec,
			"aura_regen_heal_amount": profile.aura_regen_heal_amount,
			"aura_lucky_strike_chance": profile.aura_lucky_strike_chance,
			"aura_lucky_strike_extra_damage": profile.aura_lucky_strike_extra_damage,
			"aura_double_loot_coin_chance": profile.aura_double_loot_coin_chance,
			"aura_double_loot_chip_chance": profile.aura_double_loot_chip_chance,
			"aura_double_loot_multiplier": profile.aura_double_loot_multiplier,
			"aura_low_hp_min_hp_ratio": profile.aura_low_hp_min_hp_ratio,
			"aura_low_hp_max_damage_mul": profile.aura_low_hp_max_damage_mul
		})
