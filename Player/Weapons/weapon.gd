extends Node2D
class_name Weapon

@onready var modules: Node2D = $Modules
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
var fuse : int:
	get:
		return _fuse_internal
	set(value):
		_fuse_internal = clampi(value, 1, FINAL_MAX_FUSE)
		max_level = get_max_level_for_fuse(_fuse_internal)
		_apply_fuse_sprite()

func set_level(lv):
	pass



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
