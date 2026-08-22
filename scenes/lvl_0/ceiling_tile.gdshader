shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);

uniform sampler2D noise_texture : source_color;
uniform sampler2D pattern_texture : source_color;

uniform float pattern_scale : hint_range(0.0, 1.0) = 0.2;
uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	
	// UV0 = noise texture
	vec4 noise = texture(noise_texture, UV * noise_scale);

	// UV2 = pattern texture
	vec2 pattern_uv = UV;
	vec2 edge_dist = fract(UV);
	
	pattern_uv = (max(vec2(0.5), ((edge_dist-1.0)/pattern_scale)+vec2(1.0)) - vec2(0.5)) + min(vec2(0.5), edge_dist / pattern_scale);
	
	
	vec4 pattern = texture(pattern_texture, pattern_uv);

	// Convert black/white noise to a usable mask.
	float noise_mask = noise.r;

	// Start with the base color and blend the pattern over it.
	vec3 final_color = mix(
		base_color.rgb,
		pattern.rgb,
		pattern.w
	);
	
	final_color *= 1.0 - (noise_mask * noise_strength);

	ALBEDO = final_color;
}