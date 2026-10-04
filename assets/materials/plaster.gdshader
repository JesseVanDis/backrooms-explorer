shader_type spatial;

uniform vec3 plaster_color : source_color = vec3(0.78, 0.76, 0.70);

uniform sampler2D random_texture : filter_linear, repeat_enable;

uniform highp float noise_scale : hint_range(0.001, 20.0) = 0.02;
uniform highp float fine_scale : hint_range(1.0, 1000.0) = 500;
uniform float fine_ratio : hint_range(0.0, 1.0) = 0.3;

uniform float color_variation : hint_range(0.0, 1.0) = 0.2;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;


// Local-space position passed from vertex -> fragment.
varying highp vec3 global_position;
varying vec3 v_world_normal;
varying vec3 v_world_tangent;
varying vec3 v_world_binormal;


void vertex() 
{
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_tangent = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	v_world_binormal = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// float pseudo_random_3d(vec3 p, float h1x = 12.9989, float h1y = 13.1536, float h1z = 17.8371, float h2 = 43758.54)
float pseudo_random_3d(highp vec3 p)
{
	highp float h1x = 12.9989;
	highp float h1y = 13.1536;
	highp float h1z = 17.8371;
	highp float h2 = 43758.54;
	return fract(sin(dot(p, vec3(h1x, h1y, h1z))) * h2);
}

float cell_hash_3d(highp vec3 p)
{
	return pseudo_random_3d(floor(p));
}

float value_noise_3d(highp vec3 p)
{
	highp vec3 p0 = floor(p);
	vec3 f = fract(p);

	// Smooth interpolation coordinate
	
	vec3 t = smoothstep(0.0, 1.0, f);
	// 8 corners of the cell
	float c000 = cell_hash_3d(p0 + vec3(0.0, 0.0, 0.0));
	float c100 = cell_hash_3d(p0 + vec3(1.0, 0.0, 0.0));
	float c010 = cell_hash_3d(p0 + vec3(0.0, 1.0, 0.0));
	float c110 = cell_hash_3d(p0 + vec3(1.0, 1.0, 0.0));

	float c001 = cell_hash_3d(p0 + vec3(0.0, 0.0, 1.0));
	float c101 = cell_hash_3d(p0 + vec3(1.0, 0.0, 1.0));
	float c011 = cell_hash_3d(p0 + vec3(0.0, 1.0, 1.0));
	float c111 = cell_hash_3d(p0 + vec3(1.0, 1.0, 1.0));

	// Interpolate X
	float x00 = mix(c000, c100, t.x);
	float x10 = mix(c010, c110, t.x);
	float x01 = mix(c001, c101, t.x);
	float x11 = mix(c011, c111, t.x);

	// Interpolate Y
	float y0 = mix(x00, x10, t.y);
	float y1 = mix(x01, x11, t.y);

	// Interpolate Z
	return mix(y0, y1, t.z);
}

float fractal_noise_3d(vec3 p, int iterations)
{
	float value = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;
	float amplitude_sum = 0.0;

	for (int i = 0; i < iterations; i++)
	{
		value += value_noise_3d(p * frequency) * amplitude;

		amplitude_sum += amplitude;
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value / amplitude_sum;
}

float plaster_noise(highp vec3 p, highp float scale, highp vec3 t, highp vec3 b) 
{
	p *= scale;
	// Use tangent and bitangent to project the position into surface-aligned UVs
	vec2 uv = fract(vec2(dot(p, t), dot(p, b)));
	return texture(random_texture, uv).r;
}

vec3 calculate_world_normal(highp vec3 p, float scale, vec3 t, vec3 b, vec3 n, float strength) {
	float delta = 0.01;
	float h = plaster_noise(p, scale, t, b);
	float h_x = plaster_noise(p + t * delta, scale, t, b);
	float h_y = plaster_noise(p + b * delta, scale, t, b);
	
	vec3 tangent_normal = normalize(vec3((h - h_x) * strength, (h - h_y) * strength, 1.0)); // Tangent space normal
	return normalize(t * tangent_normal.x + b * tangent_normal.y + n * tangent_normal.z);   // Convert to world space using TBN
}


void fragment() {
	highp vec3 p = global_position;
	float large_noise = fractal_noise_3d(p * noise_scale, 2);
	float fine_noise  = fractal_noise_3d(p * fine_scale, 1);

	float noise = (large_noise * (1.0 - fine_ratio)) + (fine_noise * fine_ratio); // Combine the two scales.
	float color_offset = (noise - 0.5) * color_variation;

	ALBEDO = plaster_color + vec3(color_offset);
	ROUGHNESS = roughness + (noise - 0.5) * 0.08;

	vec3 world_n = calculate_world_normal(p, fine_scale, v_world_tangent, v_world_binormal, v_world_normal, bump_strength);
	NORMAL = mat3(VIEW_MATRIX) * world_n;
}