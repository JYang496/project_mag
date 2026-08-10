extends BaseEnemy
class_name EliteEnemy

var original_material: Material
var highlight_material: ShaderMaterial
var is_highlighted: bool = false
var skill_ready: bool = true:
	set(value):
		skill_ready = value
		_refresh_elite_visual_state()
var quest_highlight_active := false
var quest_highlight_color := Color.WHITE
var _skill_activation_active := false
@onready var skill_timer: Timer = $SkillTimer

# Highlight shader code
const HIGHLIGHT_SHADER = """
shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform bool animated = true;
uniform float animation_speed : hint_range(0.1, 5.0) = 2.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.42;
uniform float body_brightness : hint_range(1.0, 1.2) = 1.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	vec4 sprite_color = texture(TEXTURE, UV);
	
	float outline = 0.0;
	// Sample surrounding pixels to create outline
	for(float x = -outline_width; x <= outline_width; x += 1.0) {
		for(float y = -outline_width; y <= outline_width; y += 1.0) {
			if(x == 0.0 && y == 0.0) continue;
			vec2 offset = vec2(x, y) * TEXTURE_PIXEL_SIZE;
			outline += texture(TEXTURE, UV + offset).a;
		}
	}
	outline = min(outline, 1.0);
	
	vec4 final_color = sprite_color;
	
	// Add outline where sprite is transparent but outline should be visible
	if(sprite_color.a == 0.0 && outline > 0.0) {
		vec4 glow_color = outline_color;
		if(animated) {
			float pulse = (sin(TIME * animation_speed) + 1.0) * 0.5;
			glow_color.a *= outline_strength * (0.72 + pulse * 0.28);
		} else {
			glow_color.a *= outline_strength;
		}
		final_color = glow_color;
	} else if(sprite_color.a > 0.0) {
		final_color.rgb *= body_brightness;
	}
	
	COLOR = final_color;
}
"""

func _ready():
	if sprite_body == null:
		push_warning("EliteEnemy missing Body sprite; highlight disabled.")
		return
	# Store original material
	original_material = sprite_body.material
	
	# Create highlight shader material
	var shader = Shader.new()
	shader.code = HIGHLIGHT_SHADER
	
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = shader
	
	# Set default shader parameters
	highlight_material.set_shader_parameter("outline_width", 1.0)
	highlight_material.set_shader_parameter("outline_color", Color(1.0, 0.72, 0.28, 1.0))
	highlight_material.set_shader_parameter("animated", false)
	highlight_material.set_shader_parameter("animation_speed", 2.0)
	highlight_material.set_shader_parameter("outline_strength", 0.42)
	highlight_material.set_shader_parameter("body_brightness", 1.0)
	highlight(true)
	_refresh_elite_visual_state()

func highlight(enable: bool = true):
	"""Toggle character highlight on/off"""
	if sprite_body == null:
		return
	is_highlighted = enable
	
	if enable:
		sprite_body.material = highlight_material
	else:
		sprite_body.material = original_material

func set_quest_highlight(active: bool, color: Color = Color.WHITE) -> void:
	if sprite_body == null:
		return
	quest_highlight_active = active
	quest_highlight_color = color
	highlight(active)
	_refresh_elite_visual_state()


func set_skill_activation_visual(active: bool) -> void:
	_skill_activation_active = active
	_refresh_elite_visual_state()


func _refresh_elite_visual_state() -> void:
	if highlight_material == null:
		return
	if quest_highlight_active:
		highlight_material.set_shader_parameter("outline_color", quest_highlight_color)
		highlight_material.set_shader_parameter("outline_strength", 0.86)
		highlight_material.set_shader_parameter("animated", true)
		highlight_material.set_shader_parameter("body_brightness", 1.04)
		return
	if _skill_activation_active:
		highlight_material.set_shader_parameter("outline_color", Color(1.0, 0.20, 0.12, 1.0))
		highlight_material.set_shader_parameter("outline_strength", 1.0)
		highlight_material.set_shader_parameter("animated", false)
		highlight_material.set_shader_parameter("body_brightness", 1.08)
		return
	highlight_material.set_shader_parameter("outline_color", Color(1.0, 0.72, 0.28, 1.0))
	highlight_material.set_shader_parameter("outline_strength", 0.58 if skill_ready else 0.36)
	highlight_material.set_shader_parameter("animated", skill_ready)
	highlight_material.set_shader_parameter("body_brightness", 1.0)

func set_highlight_color(color: Color):
	"""Change the highlight color"""
	if highlight_material:
		highlight_material.set_shader_parameter("outline_color", color)

func set_highlight_width(width: float):
	"""Change the highlight outline width"""
	if highlight_material:
		highlight_material.set_shader_parameter("outline_width", width)

func set_highlight_animated(animated: bool):
	"""Enable/disable highlight animation"""
	if highlight_material:
		highlight_material.set_shader_parameter("animated", animated)

func set_animation_speed(speed: float):
	"""Change highlight animation speed"""
	if highlight_material:
		highlight_material.set_shader_parameter("animation_speed", speed)


# Alternative simple highlight method using modulation (less fancy but simpler)
func simple_highlight(enable: bool = true):
	"""Simple highlight using sprite modulation"""
	if enable:
		sprite_body.modulate = Color(1.5, 1.5, 1.0, 1.0)  # Yellowish tint
		# Optional: add a simple scaling effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite_body, "scale", Vector2(1.1, 1.1), 0.5)
		tween.tween_property(sprite_body, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		sprite_body.modulate = Color.WHITE
		# Stop any tweens
		if has_method("kill"):
			get_tree().get_tween().kill()


func _on_skill_timer_timeout() -> void:
	skill_ready = true
