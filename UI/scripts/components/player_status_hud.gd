extends Control
class_name PlayerStatusHud

const HUD_SIZE := Vector2(324.0, 88.0)
const BAR_WIDTH := 198.0
const HP_HEIGHT := 20.0
const SHIELD_HEIGHT := 7.0
const ENERGY_CELL_WIDTH := 54.0
const ENERGY_HALF_CELL_WIDTH := 27.0
const ENERGY_CELL_HEIGHT := 20.0
const ENERGY_CELL_GAP := 5.0
const HP_GHOST_HOLD_SECONDS := 0.25
const HP_GHOST_CATCHUP_SECONDS := 0.6
const DAMAGE_GHOST_COLOR := Color(0.96, 0.98, 1.0, 0.92)
const HEAL_GHOST_COLOR := Color(0.30, 1.0, 0.82, 0.88)
const ENERGY_CAPACITIES := [50.0, 50.0, 25.0]
const ENERGY_SOURCE_REGIONS := [
	Rect2(8.0, 8.0, 618.0, 136.0),
	Rect2(642.0, 8.0, 618.0, 136.0),
	Rect2(1276.0, 8.0, 309.0, 136.0),
]
const HP_TEXTURE := preload("res://UI/themes/player_status_hud/generated/hp_fill.png")
const SHIELD_TEXTURE := preload("res://UI/themes/player_status_hud/generated/shield_fill.png")
const ENERGY_TEXTURE := preload("res://UI/themes/player_status_hud/generated/energy_125_fill.png")
const AMMO_TEXTURE := preload("res://UI/themes/player_status_hud/generated/ammo_icon.png")

var _hp_clip: Control
var _hp_fill: TextureRect
var _hp_ghost_clip: Control
var _hp_ghost_fill: TextureRect
var _hp_ghost_material: ShaderMaterial
var _shield_clip: Control
var _energy_cells: Array[TextureRect] = []
var _energy_fill_clips: Array[Control] = []
var _energy_fills: Array[TextureRect] = []
var _hp_label: Label
var _ammo_icon: TextureRect
var _ammo_label: Label
var _skill_cost := 0.0
var _current_energy := 0.0
var _display_energy := 0.0
var _cooldown_ratio := 0.0
var _has_health_sample := false
var _target_hp_ratio := 0.0
var _display_hp_ratio := 0.0
var _ghost_hp_ratio := 0.0
var _hp_animation_start_ratio := 0.0
var _hp_animation_elapsed := 0.0
var _hp_animation_mode: StringName = &"none"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = HUD_SIZE
	size = HUD_SIZE
	_hp_clip = _make_clip("HpClip", Vector2.ZERO, Vector2(BAR_WIDTH, HP_HEIGHT))
	var hp_track := _make_texture(self, "HpTrack", HP_TEXTURE, Vector2(BAR_WIDTH, HP_HEIGHT))
	hp_track.modulate = Color(0.08, 0.22, 0.14, 0.42)
	move_child(hp_track, 0)
	_hp_ghost_clip = _make_clip("HpGhostClip", Vector2.ZERO, Vector2(BAR_WIDTH, HP_HEIGHT))
	_hp_ghost_fill = _make_texture(_hp_ghost_clip, "HpGhostFill", HP_TEXTURE, Vector2(BAR_WIDTH, HP_HEIGHT))
	_hp_ghost_material = _create_ghost_material()
	_hp_ghost_fill.material = _hp_ghost_material
	move_child(_hp_ghost_clip, _hp_clip.get_index())
	_hp_fill = _make_texture(_hp_clip, "HpFill", HP_TEXTURE, Vector2(BAR_WIDTH, HP_HEIGHT))
	_shield_clip = _make_clip("ShieldClip", Vector2(0.0, HP_HEIGHT), Vector2(BAR_WIDTH, SHIELD_HEIGHT))
	var shield_track := _make_texture(self, "ShieldTrack", SHIELD_TEXTURE, Vector2(BAR_WIDTH, SHIELD_HEIGHT))
	shield_track.position = Vector2(0.0, HP_HEIGHT)
	shield_track.modulate = Color(0.15, 0.40, 0.65, 0.48)
	move_child(shield_track, 1)
	_make_texture(_shield_clip, "ShieldFill", SHIELD_TEXTURE, Vector2(BAR_WIDTH, SHIELD_HEIGHT))
	_build_energy_cells()
	_build_hp_label()
	_build_ammo_display()
	_hp_clip.size.x = 0.0
	_hp_ghost_clip.visible = false
	set_energy(0.0, 125.0)
	set_ammo(0, 0, false)
	set_process(true)

func set_health(current_hp: int, max_hp: int, current_shield: int = 0, max_shield: int = 0) -> void:
	var safe_max := maxi(max_hp, 1)
	var hp_ratio := clampf(float(current_hp) / float(safe_max), 0.0, 1.0)
	var shield_ratio := clampf(float(current_shield) / float(maxi(max_shield, 1)), 0.0, 1.0)
	if not _has_health_sample:
		_has_health_sample = true
		_target_hp_ratio = hp_ratio
		_display_hp_ratio = hp_ratio
		_ghost_hp_ratio = hp_ratio
		_apply_hp_visuals()
	elif not is_equal_approx(hp_ratio, _target_hp_ratio):
		_begin_hp_animation(hp_ratio)
	_shield_clip.size.x = BAR_WIDTH * shield_ratio
	_shield_clip.visible = current_shield > 0
	_hp_label.text = "%d / %d" % [maxi(current_hp, 0), safe_max]
	_hp_fill.modulate = _health_color(_target_hp_ratio)

func _process(delta: float) -> void:
	if _hp_animation_mode == &"none":
		return
	_hp_animation_elapsed += maxf(delta, 0.0)
	if _hp_animation_elapsed <= HP_GHOST_HOLD_SECONDS:
		return
	var catchup_elapsed := _hp_animation_elapsed - HP_GHOST_HOLD_SECONDS
	var progress := clampf(catchup_elapsed / HP_GHOST_CATCHUP_SECONDS, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, progress)
	if _hp_animation_mode == &"damage":
		_ghost_hp_ratio = lerpf(_hp_animation_start_ratio, _target_hp_ratio, eased)
	else:
		_display_hp_ratio = lerpf(_hp_animation_start_ratio, _target_hp_ratio, eased)
	_apply_hp_visuals()
	if progress >= 1.0:
		_display_hp_ratio = _target_hp_ratio
		_ghost_hp_ratio = _target_hp_ratio
		_hp_animation_mode = &"none"
		_hp_ghost_clip.visible = false
		_apply_hp_visuals()

func _begin_hp_animation(next_ratio: float) -> void:
	var previous_target := _target_hp_ratio
	_target_hp_ratio = next_ratio
	_hp_animation_elapsed = 0.0
	if next_ratio < previous_target:
		_hp_animation_mode = &"damage"
		_display_hp_ratio = next_ratio
		_ghost_hp_ratio = maxf(_ghost_hp_ratio, previous_target)
		_hp_animation_start_ratio = _ghost_hp_ratio
		_set_ghost_color(DAMAGE_GHOST_COLOR)
	else:
		_hp_animation_mode = &"heal"
		_hp_animation_start_ratio = _display_hp_ratio
		_ghost_hp_ratio = next_ratio
		_set_ghost_color(HEAL_GHOST_COLOR)
	_hp_ghost_clip.visible = true
	_hp_fill.modulate = _health_color(_target_hp_ratio)
	_apply_hp_visuals()

func _apply_hp_visuals() -> void:
	_hp_clip.size = Vector2(BAR_WIDTH * clampf(_display_hp_ratio, 0.0, 1.0), HP_HEIGHT)
	_hp_ghost_clip.size = Vector2(BAR_WIDTH * clampf(_ghost_hp_ratio, 0.0, 1.0), HP_HEIGHT)

func _create_ghost_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 ghost_color : source_color = vec4(1.0);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float material_detail = mix(0.72, 1.18, smoothstep(0.0, 0.85, luminance));
	COLOR = vec4(ghost_color.rgb * material_detail, source.a * ghost_color.a);
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("ghost_color", DAMAGE_GHOST_COLOR)
	return shader_material

func _set_ghost_color(color: Color) -> void:
	if _hp_ghost_material != null:
		_hp_ghost_material.set_shader_parameter("ghost_color", color)

func set_energy(current: float, max_value: float) -> void:
	var safe_max := maxf(max_value, 1.0)
	_current_energy = clampf(current, 0.0, safe_max)
	_display_energy = 125.0 * (_current_energy / safe_max)
	_update_energy_cells()
	_refresh_energy_tint()

func set_skill_cost(cost: float) -> void:
	_skill_cost = maxf(cost, 0.0)
	_refresh_energy_tint()

func set_cooldown_ratio(ratio: float) -> void:
	_cooldown_ratio = clampf(ratio, 0.0, 1.0)
	_refresh_energy_tint()

func set_ammo(current: int, maximum: int, enabled: bool = true, state: StringName = &"normal", tooltip: String = "") -> void:
	var safe_max := maxi(maximum, 0)
	var safe_current := clampi(current, 0, safe_max) if safe_max > 0 else 0
	_ammo_icon.visible = enabled
	_ammo_label.visible = enabled
	_ammo_label.text = "%02d / %02d" % [safe_current, safe_max]
	_ammo_label.tooltip_text = tooltip
	var warning := state == &"warning" or (safe_max > 0 and safe_current <= maxi(1, int(ceil(float(safe_max) * 0.25))))
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.26) if warning else Color(0.72, 0.94, 1.0))
	_ammo_icon.modulate = Color(1.0, 0.72, 0.35) if state == &"reloading" else Color.WHITE

func _make_clip(node_name: String, node_position: Vector2, node_size: Vector2) -> Control:
	var clip := Control.new()
	clip.name = node_name
	clip.position = node_position
	clip.size = node_size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	return clip

func _make_texture(parent: Control, node_name: String, texture: Texture2D, texture_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2.ZERO
	rect.texture = texture
	rect.set_deferred("size", texture_size)
	rect.size = texture_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.reset_size()
	rect.size = texture_size
	return rect

func _build_hp_label() -> void:
	_hp_label = Label.new()
	_hp_label.name = "HpValue"
	_hp_label.position = Vector2(BAR_WIDTH + 7.0, -1.0)
	_hp_label.size = Vector2(79.0, 28.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 13)
	_hp_label.add_theme_color_override("font_color", Color(0.80, 1.0, 0.88))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_hp_label)

func _build_ammo_display() -> void:
	_ammo_icon = TextureRect.new()
	_ammo_icon.name = "AmmoIcon"
	_ammo_icon.position = Vector2(181.0, 40.0)
	_ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ammo_icon.custom_minimum_size = Vector2.ZERO
	_ammo_icon.texture = AMMO_TEXTURE
	_ammo_icon.size = Vector2(34.0, 28.0)
	_ammo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ammo_icon)
	_ammo_icon.reset_size()
	_ammo_icon.size = Vector2(34.0, 28.0)
	_ammo_label = Label.new()
	_ammo_label.name = "AmmoValue"
	_ammo_label.position = Vector2(216.0, 41.0)
	_ammo_label.size = Vector2(72.0, 25.0)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ammo_label.add_theme_font_size_override("font_size", 14)
	_ammo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_ammo_label.add_theme_constant_override("shadow_offset_x", 1)
	_ammo_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_ammo_label)

func _refresh_energy_tint() -> void:
	var can_cast := _skill_cost <= 0.0 or _current_energy >= _skill_cost
	var alpha := lerpf(1.0, 0.42, _cooldown_ratio)
	for fill in _energy_fills:
		fill.modulate = Color(1.0, 1.0, 1.0, alpha) if can_cast else Color(1.0, 0.36, 0.28, alpha)

func _build_energy_cells() -> void:
	var x := 0.0
	for index in range(ENERGY_CAPACITIES.size()):
		var cell_width := ENERGY_HALF_CELL_WIDTH if index == 2 else ENERGY_CELL_WIDTH
		var atlas := AtlasTexture.new()
		atlas.atlas = ENERGY_TEXTURE
		atlas.region = ENERGY_SOURCE_REGIONS[index]
		var track := _make_texture(self, "EnergyTrack%d" % index, atlas, Vector2(cell_width, ENERGY_CELL_HEIGHT))
		track.position = Vector2(x, 40.0)
		track.modulate = Color(0.55, 0.28, 0.02, 0.38)
		_energy_cells.append(track)
		var clip := _make_clip("EnergyClip%d" % index, Vector2(x, 40.0), Vector2(cell_width, ENERGY_CELL_HEIGHT))
		var fill := _make_texture(clip, "EnergyFill%d" % index, atlas, Vector2(cell_width, ENERGY_CELL_HEIGHT))
		_energy_fill_clips.append(clip)
		_energy_fills.append(fill)
		x += cell_width + ENERGY_CELL_GAP

func _update_energy_cells() -> void:
	var remaining := _display_energy
	for index in range(ENERGY_CAPACITIES.size()):
		var capacity: float = ENERGY_CAPACITIES[index]
		var cell_width := ENERGY_HALF_CELL_WIDTH if index == 2 else ENERGY_CELL_WIDTH
		var fill_ratio := clampf(remaining / capacity, 0.0, 1.0)
		_energy_fill_clips[index].size.x = cell_width * fill_ratio
		remaining = maxf(0.0, remaining - capacity)

func _health_color(ratio: float) -> Color:
	if ratio <= 0.18:
		return Color(1.0, 0.32, 0.30)
	if ratio <= 0.35:
		return Color(1.0, 0.72, 0.30)
	return Color.WHITE
