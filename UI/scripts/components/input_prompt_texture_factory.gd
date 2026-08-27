extends RefCounted

const INPUT_PROMPT_ATLAS := preload("res://asset/images/ui/input_prompts/kenney_pixel/input_prompts_tilemap.png")
const INPUT_PROMPT_TILE_SIZE := 16
const INPUT_PROMPT_TILE_STRIDE := 17
const SPACE_PROMPT_START_COORD := Vector2i(31, 6)
const SPACE_PROMPT_TILE_COUNT := 3
const ESCAPE_PROMPT_REGION := Rect2(289, 0, 16, 16)

static var _space_prompt_texture: Texture2D
static var _escape_prompt_texture: Texture2D


static func space_prompt_texture() -> Texture2D:
	if _space_prompt_texture != null:
		return _space_prompt_texture
	var atlas_image := INPUT_PROMPT_ATLAS.get_image()
	var prompt_image := Image.create_empty(
		INPUT_PROMPT_TILE_SIZE * SPACE_PROMPT_TILE_COUNT,
		INPUT_PROMPT_TILE_SIZE,
		false,
		atlas_image.get_format()
	)
	for tile_index in SPACE_PROMPT_TILE_COUNT:
		var source_position := Vector2i(
			(SPACE_PROMPT_START_COORD.x + tile_index) * INPUT_PROMPT_TILE_STRIDE,
			SPACE_PROMPT_START_COORD.y * INPUT_PROMPT_TILE_STRIDE
		)
		prompt_image.blit_rect(
			atlas_image,
			Rect2i(source_position, Vector2i(INPUT_PROMPT_TILE_SIZE, INPUT_PROMPT_TILE_SIZE)),
			Vector2i(tile_index * INPUT_PROMPT_TILE_SIZE, 0)
		)
	_space_prompt_texture = ImageTexture.create_from_image(prompt_image)
	return _space_prompt_texture


static func escape_prompt_texture() -> Texture2D:
	if _escape_prompt_texture != null:
		return _escape_prompt_texture
	var texture := AtlasTexture.new()
	texture.atlas = INPUT_PROMPT_ATLAS
	texture.region = ESCAPE_PROMPT_REGION
	_escape_prompt_texture = texture
	return _escape_prompt_texture
