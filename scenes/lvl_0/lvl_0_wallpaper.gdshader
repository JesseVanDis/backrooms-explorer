shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);

uniform sampler2D noise_texture : source_color;
uniform sampler2D pattern_texture : source_color;

uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	
	// UV0 = noise texture
	vec4 noise = texture(noise_texture, UV * noise_scale);

	// UV2 = pattern texture
	vec4 pattern = texture(pattern_texture, UV);

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