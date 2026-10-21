shader_type spatial;
// render_mode unshaded;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D noise_texture : source_color;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.152;
uniform float noise_scale : hint_range(0.0, 100.0) = 14.0;

varying float local_y_pos;

float curve(float x, float k)
{
	return ((1.0/-(x+k)) * k + 1.0) * (k+1.0);
}

void vertex() {
	local_y_pos = VERTEX.y;
}

void fragment() {
	vec2 uv = UV * noise_scale;
	float noise = texture(noise_texture, uv).r;

	vec3 final_color = base_color.rgb;
	final_color *= 1.0 - (noise * noise_strength);
	final_color *= 1.0 - clamp(curve(-local_y_pos * 1.3, 0.3), 0.0, 1.0);

	ALBEDO = final_color;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	vec3 normal_or = NORMAL;
	vec3 normal_new = normalize(mat3(VIEW_MATRIX) * vec3(0,1,0));
	NORMAL = mix(normal_new, normal_or, clamp((-local_y_pos) * 1.0, 0.0, 1.0));
	//NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(0,1,0));
}