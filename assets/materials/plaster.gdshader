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
varying vec3 v_world_normal;
varying vec3 v_world_tangent;
varying vec3 v_world_binormal;


void vertex() 
{
	local_position = VERTEX;
	v_normal = NORMAL;
	v_tangent = TANGENT;
	v_binormal = BINORMAL;
	v_node_position = MODEL_MATRIX[3].xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_tangent = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	v_world_binormal = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}

float plaster_noise(vec3 p, float scale, vec3 t, vec3 b) 
{
	p *= scale;
	// Use tangent and bitangent to project the position into surface-aligned UVs
	vec2 uv = vec2(dot(p, t), dot(p, b));
	return texture(random_texture, uv).r;
}

vec3 calculate_world_normal(vec3 p, float scale, vec3 t, vec3 b, vec3 n, float strength) {
	float delta = 0.01;
	float h = plaster_noise(p, scale, t, b);
	float h_x = plaster_noise(p + t * delta, scale, t, b);
	float h_y = plaster_noise(p + b * delta, scale, t, b);
	
	vec3 tangent_normal = normalize(vec3((h - h_x) * strength, (h - h_y) * strength, 1.0)); // Tangent space normal
	return normalize(t * tangent_normal.x + b * tangent_normal.y + n * tangent_normal.z);   // Convert to world space using TBN
}


void fragment() {
	vec3 p = local_position + v_node_position;
	float large_noise = plaster_noise(p, noise_scale, v_tangent, v_binormal);
	float fine_noise  = plaster_noise(p, fine_scale, v_tangent, v_binormal);

	float noise = (large_noise * 0.7) + (fine_noise * 0.3); // Combine the two scales.
	float color_offset = (noise - 0.5) * color_variation;

	ALBEDO = plaster_color + vec3(color_offset);
	ROUGHNESS = roughness + (noise - 0.5) * 0.08;

	vec3 world_n = calculate_world_normal(p, fine_scale, v_world_tangent, v_world_binormal, v_world_normal, bump_strength);
	NORMAL = (VIEW_MATRIX * vec4(world_n, 0.0)).xyz;
}