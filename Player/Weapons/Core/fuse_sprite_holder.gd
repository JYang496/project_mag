extends Node
class_name FuseSpriteHolder

@export var fuse_texture_1: Texture2D
@export var fuse_texture_2: Texture2D
@export var fuse_texture_3: Texture2D

func get_fuse_textures() -> Dictionary:
	return {
		1: fuse_texture_1,
		2: fuse_texture_2,
		3: fuse_texture_3,
	}
