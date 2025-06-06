extends BaseEnemy
class_name EliteEnemy

var original_material: Material
var highlight_material: ShaderMaterial
var is_highlighted: bool = false
var skill_ready : bool = true

# Highlight shader code
const HIGHLIGHT_SHADER = """
shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform bool animated = true;
uniform float animation_speed : hint_range(0.1, 5.0) = 2.0;

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
			glow_color.a *= (0.5 + pulse * 0.5);
		}
		final_color = glow_color;
	} else if(sprite_color.a > 0.0) {
		// Brighten the sprite itself slightly
		final_color.rgb *= 1.2;
	}
	
	COLOR = final_color;
}
"""

func _ready():
	hit_box_dot.hitbox_owner = self
	# Scale up the body
	sprite_body.scale = Vector2(1.5, 1.5)
	# Store original material
	original_material = sprite_body.material
	
	# Create highlight shader material
	var shader = Shader.new()
	shader.code = HIGHLIGHT_SHADER
	
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = shader
	
	# Set default shader parameters
	highlight_material.set_shader_parameter("outline_width", 1.0)
	highlight_material.set_shader_parameter("outline_color", Color.YELLOW)
	highlight_material.set_shader_parameter("animated", true)
	highlight_material.set_shader_parameter("animation_speed", 2.0)
	highlight(true)

func highlight(enable: bool = true):
	"""Toggle character highlight on/off"""
	is_highlighted = enable
	
	if enable:
		sprite_body.material = highlight_material
	else:
		sprite_body.material = original_material

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
	pass # Replace with function body.
