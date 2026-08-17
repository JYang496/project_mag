extends Node2D
class_name Skills

@export var cooldown: float = 0.0
@export var energy_cost: float = 50.0
@export var skill_tags: Array[StringName] = []

var _player: Player
var _on_cooldown := false
var _cooldown_remaining: float = 0.0
var _cooldown_serial: int = 0
var _finished_action_ids: Dictionary = {}

func _ready() -> void:
	call_deferred("_bind_player_and_initialize")

func _bind_player_and_initialize() -> void:
	_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		await get_tree().process_frame
		_player = _resolve_player()
	if _player == null or not is_instance_valid(_player):
		push_warning("%s failed to initialize: player not found." % name)
		return
	var callable_ref := Callable(self, "_on_player_active_skill_requested")
	if _player.has_signal("player_active_skill"):
		if not _player.player_active_skill.is_connected(callable_ref):
			_player.player_active_skill.connect(callable_ref)
	elif not _player.active_skill.is_connected(callable_ref):
		_player.active_skill.connect(callable_ref)
	on_skill_ready()

func _resolve_player() -> Player:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		return PlayerData.player
	var current: Node = get_parent()
	while current:
		if current is Player:
			return current as Player
		current = current.get_parent()
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node and player_node is Player:
		return player_node as Player
	return null

func _on_player_active_skill_requested() -> void:
	if _on_cooldown:
		return
	if not can_activate():
		return
	var spent_energy := get_energy_cost()
	if not _pay_energy_cost():
		return
	var context := SkillActionContext.create(
		self,
		_player,
		_player.get_main_weapon(),
		get_skill_tags(),
		spent_energy
	)
	if not activate_skill(context):
		_player.add_energy(spent_energy)
		return
	emit_skill_event(WeaponEvent.SKILL_CAST_COMMITTED, context)
	_player.player_skill_activated.emit(self)
	if finishes_on_commit():
		finish_skill_action(context, _player.global_position)
	if cooldown > 0.0:
		_start_cooldown()

func _start_cooldown() -> void:
	_cooldown_serial += 1
	var serial := _cooldown_serial
	_on_cooldown = true
	_cooldown_remaining = maxf(cooldown, 0.0)
	await get_tree().create_timer(cooldown).timeout
	if serial != _cooldown_serial:
		return
	_on_cooldown = false
	_cooldown_remaining = 0.0

func force_cooldown_ready() -> void:
	_cooldown_serial += 1
	_on_cooldown = false
	_cooldown_remaining = 0.0

func _physics_process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - maxf(delta, 0.0))

func on_skill_ready() -> void:
	pass

func can_activate() -> bool:
	return true

func activate_skill(_context: SkillActionContext) -> bool:
	return false

func finishes_on_commit() -> bool:
	return false

func get_skill_tags() -> Array[StringName]:
	return skill_tags.duplicate()

func finish_skill_action(context: SkillActionContext, end_position: Vector2) -> void:
	if _finished_action_ids.has(context.action_id):
		return
	context.finish_at(end_position)
	_finished_action_ids[context.action_id] = true
	emit_skill_event(WeaponEvent.SKILL_CAST_FINISHED, context)
	while _finished_action_ids.size() > 64:
		_finished_action_ids.erase(_finished_action_ids.keys()[0])

func emit_skill_event(event_type: StringName, context: SkillActionContext) -> void:
	var event := WeaponEvent.create(event_type, context.linked_weapon).with_context(context)
	_player.broadcast_weapon_event(event)

func get_energy_cost() -> float:
	return maxf(energy_cost, 0.0)

func _pay_energy_cost() -> bool:
	var required := get_energy_cost()
	if required <= 0.0:
		return true
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method("consume_energy"):
		return false
	return bool(_player.call("consume_energy", required))

func get_cooldown_remaining() -> float:
	return _cooldown_remaining

func get_cooldown_duration() -> float:
	return maxf(cooldown, 0.0)

func get_cooldown_ratio() -> float:
	if cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / cooldown, 0.0, 1.0)
