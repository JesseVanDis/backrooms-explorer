shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D noise_texture : source_color;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.152;
uniform float noise_scale : hint_range(0.0, 100.0) = 14.0;

void fragment() {
	vec2 uv = UV * noise_scale;
	float noise = texture(noise_texture, uv).r;

	vec3 final_color = base_color.rgb;
	final_color *= 1.0 - (noise * noise_strength);

	ALBEDO = final_color;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}