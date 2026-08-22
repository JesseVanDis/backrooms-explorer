shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);

uniform sampler2D noise_texture : source_color;

uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.0, 100.0) = 1.0;

uniform float carpet_bump : hint_range(0.0, 5.0) = 1.0;
uniform float bump_size : hint_range(0.001, 0.1) = 0.01;

void fragment() {

	// Scaled UV coordinates.
	vec2 uv = UV * noise_scale;

	// Center height.
	float h = texture(noise_texture, uv).r;

	// Sample neighboring pixels.
	float h_x1 = texture(noise_texture, uv + vec2(bump_size, 0.0)).r;
	float h_x2 = texture(noise_texture, uv - vec2(bump_size, 0.0)).r;

	float h_y1 = texture(noise_texture, uv + vec2(0.0, bump_size)).r;
	float h_y2 = texture(noise_texture, uv - vec2(0.0, bump_size)).r;

	// Height gradients.
	float dx = h_x1 - h_x2;
	float dy = h_y1 - h_y2;

	// Construct a tangent-space normal from the height map.
	vec3 carpet_normal = normalize(
		vec3(
			-dx * carpet_bump,
			-dy * carpet_bump,
			1.0
		)
	);

	NORMAL_MAP = carpet_normal * 0.5 + 0.5;

	// Your original color.
	float noise_mask = h;

	vec3 final_color = base_color.rgb;
	final_color *= 1.0 - (noise_mask * noise_strength);

	ALBEDO = final_color;
}