extends RefCounted
class_name WeaponFuseVisualController

var weapon: Weapon
var fuse_sprites: Dictionary = {}

func setup(source_weapon: Weapon) -> void:
	weapon = source_weapon

func apply_fuse_sprite() -> void:
	if weapon == null or weapon.sprite == null:
		return
	var tex: Texture2D = fuse_sprites.get(weapon.fuse, fuse_sprites.get(1))
	if tex:
		weapon.sprite.texture = tex
		var blade_sprite_node := weapon.get_node_or_null("BladeAnchor/BladeSprite")
		if blade_sprite_node is Sprite2D:
			(blade_sprite_node as Sprite2D).texture = tex
		if weapon.has_method("_on_fuse_texture_changed"):
			weapon.call("_on_fuse_texture_changed")

func load_fuse_sprites() -> bool:
	fuse_sprites.clear()
	if weapon == null:
		return false
	if weapon.fuse_sprite_holder:
		var overrides := weapon.fuse_sprite_holder.get_fuse_textures()
		for fuse_level in overrides.keys():
			var tex: Texture2D = overrides[fuse_level]
			if tex:
				fuse_sprites[fuse_level] = tex
	if fuse_sprites.is_empty() and weapon.sprite and weapon.sprite.texture:
		fuse_sprites[1] = weapon.sprite.texture
	apply_fuse_sprite()
	return true

func clear_for_weapon_exit() -> void:
	fuse_sprites.clear()
