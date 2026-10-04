shader_type spatial;

uniform vec3 plaster_color : source_color = vec3(0.78, 0.76, 0.70);

uniform sampler2D random_texture : filter_linear, repeat_enable;

uniform float noise_scale : hint_range(0.001, 2.0) = 0.02;
uniform float fine_scale : hint_range(0.1, 10.0) = 1.4;

uniform float color_variation : hint_range(0.0, 1.0) = 0.2;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;


// Local-space position passed from vertex -> fragment.
varying vec3 local_position;
varying vec3 v_normal;
varying vec3 v_tangent;
varying vec3 v_binormal;
varying vec3 v_node_position;


void vertex() 
{
	local_position = VERTEX;
	v_normal = NORMAL;
	v_tangent = TANGENT;
	v_binormal = BINORMAL;
	v_node_position = MODEL_MATRIX[3].xyz;
}

float plaster_noise(vec3 p, float scale, vec3 t, vec3 b) 
{
	p *= scale;
	// Use tangent and bitangent to project the position into surface-aligned UVs
	vec2 uv = vec2(dot(p, t), dot(p, b));
	return texture(random_texture, uv).r;
}


void fragment() {
	vec3 p = local_position + v_node_position;
	float large_noise = plaster_noise(p, noise_scale, v_tangent, v_binormal);
	float fine_noise  = plaster_noise(p, fine_scale, v_tangent, v_binormal);

	float noise = (large_noise * 0.7) + (fine_noise * 0.3); // Combine the two scales.
	float color_offset = (noise - 0.5) * color_variation;

	ALBEDO = plaster_color + vec3(color_offset);
	ROUGHNESS = roughness + (noise - 0.5) * 0.08;

	float bump =
		(fine_noise - 0.5) * bump_strength;

	//NORMAL_MAP = vec3(
	//	bump,
	//	bump,
	//	1.0
	//);
}