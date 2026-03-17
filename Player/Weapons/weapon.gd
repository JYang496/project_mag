extends Node2D
class_name Weapon

@onready var modules: WeaponModules = $Modules
var MAX_MODULE_NUMBER = 3
@onready var sprite: Sprite2D = $Sprite
@onready var fuse_sprite_holder: FuseSpriteHolder = get_node_or_null("FuseSprites")
@onready var _fuse_sprites_initialized = _load_fuse_sprites()
var on_hit_plugins: Array[Node] = []

# Common variables for weapons
const FUSE_LEVEL_CAPS: Dictionary = {
	1: 3,
	2: 5,
	3: 7,
}
var level : int
var FINAL_MAX_FUSE : int = 3
var FINAL_MAX_LEVEL : int = 7
var max_level : int = FUSE_LEVEL_CAPS[1]
var _fuse_internal : int = 1
var fuse_sprites: Dictionary = {}
var branch_id: String = ""
var branch_definition: WeaponBranchDefinition
var branch_behavior: WeaponBranchBehavior
var fuse : int:
	get:
		return _fuse_internal
	set(value):
		_fuse_internal = clampi(value, 1, FINAL_MAX_FUSE)
		max_level = get_max_level_for_fuse(_fuse_internal)
		_apply_fuse_sprite()

func set_level(lv):
	pass

func calculate_status() -> void:
	# Recompute derived runtime stats after module changes.
	if has_method("sync_stats"):
		call("sync_stats")
	validate_module_compatibility()



func set_max_level(ml : int):
	var fuse_cap: int = get_max_level_for_fuse(fuse)
	max_level = clampi(ml, 1, fuse_cap)

func get_max_level_for_fuse(fuse_level: int) -> int:
	return FUSE_LEVEL_CAPS.get(fuse_level, FINAL_MAX_LEVEL)

func _apply_fuse_sprite() -> void:
	if not sprite:
		return
	var tex: Texture2D = fuse_sprites.get(fuse, fuse_sprites.get(1))
	if tex:
		sprite.texture = tex

func _load_fuse_sprites() -> bool:
	fuse_sprites.clear()
	if fuse_sprite_holder:
		var overrides := fuse_sprite_holder.get_fuse_textures()
		for fuse_level in overrides.keys():
			var tex: Texture2D = overrides[fuse_level]
			if tex:
				fuse_sprites[fuse_level] = tex
	if fuse_sprites.is_empty() and sprite and sprite.texture:
		fuse_sprites[1] = sprite.texture
	_apply_fuse_sprite()
	return true

func register_on_hit_plugin(plugin: Node) -> void:
	if plugin and not on_hit_plugins.has(plugin):
		on_hit_plugins.append(plugin)

func unregister_on_hit_plugin(plugin: Node) -> void:
	on_hit_plugins.erase(plugin)

func on_hit_target(target: Node) -> void:
	for plugin in on_hit_plugins:
		if is_instance_valid(plugin) and plugin.has_method("apply_on_hit"):
			plugin.apply_on_hit(self, target)

func supports_projectiles() -> bool:
	return false

func supports_melee_contact() -> bool:
	return false

func _ready() -> void:
	_apply_branch_behavior_if_needed()
	call_deferred("validate_module_compatibility")

func set_branch(new_branch_id: String) -> bool:
	var normalized_id := str(new_branch_id)
	if normalized_id == "":
		return false
	var scene_path := scene_file_path
	var branch_def := DataHandler.read_weapon_branch_definition(scene_path, normalized_id)
	if branch_def == null:
		return false
	if fuse < int(branch_def.unlock_fuse):
		return false
	branch_id = normalized_id
	branch_definition = branch_def
	_apply_branch_behavior_if_needed(true)
	if has_method("set_level") and level > 0:
		set_level(level)
	return true

func get_branch_options() -> Array[WeaponBranchDefinition]:
	return DataHandler.read_weapon_branch_options(scene_file_path, fuse)

func _apply_branch_behavior_if_needed(force_refresh: bool = false) -> void:
	if branch_id == "":
		if force_refresh:
			_clear_branch_behavior()
		return
	if branch_definition == null or force_refresh:
		branch_definition = DataHandler.read_weapon_branch_definition(scene_file_path, branch_id)
	if branch_definition == null:
		if force_refresh:
			branch_id = ""
			_clear_branch_behavior()
		return
	if branch_definition.behavior_scene == null:
		if force_refresh:
			_clear_branch_behavior()
		return
	if branch_behavior == null:
		for child in get_children():
			var existing := child as WeaponBranchBehavior
			if existing:
				branch_behavior = existing
				branch_behavior.setup(self)
				break
	if branch_behavior and is_instance_valid(branch_behavior):
		if not force_refresh:
			return
		_clear_branch_behavior()
	var behavior_instance := branch_definition.behavior_scene.instantiate() as WeaponBranchBehavior
	if behavior_instance == null:
		push_warning("Weapon branch '%s' behavior is not WeaponBranchBehavior on weapon '%s'." % [branch_id, name])
		return
	branch_behavior = behavior_instance
	add_child(branch_behavior)
	branch_behavior.setup(self)
	branch_behavior.on_weapon_ready()

func _clear_branch_behavior() -> void:
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_removed()
		branch_behavior.queue_free()
	branch_behavior = null

func get_normalized_weapon_traits() -> Array[StringName]:
	var traits: Array[StringName] = []
	if modules and modules.has_method("get_normalized_weapon_traits"):
		traits = modules.get_normalized_weapon_traits()
	if supports_projectiles() and not traits.has(CombatTrait.PROJECTILE):
		traits.append(CombatTrait.PROJECTILE)
	if supports_melee_contact() and not traits.has(CombatTrait.MELEE):
		traits.append(CombatTrait.MELEE)
	return traits

func has_weapon_trait(trait_name: Variant) -> bool:
	var normalized := CombatTrait.normalize(trait_name)
	if normalized == StringName():
		return false
	return get_normalized_weapon_traits().has(normalized)

func has_any_weapon_traits(required_traits: Array[StringName]) -> bool:
	if required_traits.is_empty():
		return true
	var traits := get_normalized_weapon_traits()
	for required_trait in required_traits:
		if traits.has(required_trait):
			return true
	return false

func validate_module_compatibility() -> void:
	if modules == null:
		return
	for child in modules.get_children():
		var module_node := child as Module
		if module_node == null:
			continue
		module_node.weapon = self
		if module_node.can_apply_to_weapon(self):
			continue
		push_warning(
			"Module '%s' is incompatible with weapon '%s'; removing module." %
			[module_node.name, name]
		)
		module_node.call_deferred("queue_free")

func get_weapon_capabilities() -> Dictionary:
	return {
		"projectiles": supports_projectiles(),
		"melee_contact": supports_melee_contact(),
	}

func _on_tree_exited() -> void:
	on_hit_plugins.clear()
	branch_behavior = null
	branch_definition = null
