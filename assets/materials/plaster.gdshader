shader_type spatial;

uniform vec3 plaster_color : source_color = vec3(0.78, 0.76, 0.70);

uniform sampler2D random_texture : filter_linear, repeat_enable;

uniform float noise_scale : hint_range(0.01, 2.0) = 1.0;
uniform float fine_scale : hint_range(0.1, 10.0) = 2.0;

uniform float color_variation : hint_range(0.0, 1.0) = 0.08;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.88;


// Local-space position passed from vertex -> fragment.
varying vec3 local_position;
varying vec3 v_normal;
varying vec3 v_tangent;
varying vec3 v_binormal;


void vertex() 
{
	local_position = VERTEX;
	v_normal = NORMAL;
	v_tangent = TANGENT;
	v_binormal = BINORMAL;
}

float random_xy(vec3 p) { return texture(random_texture, p.xy).r; }
float random_xz(vec3 p) { return texture(random_texture, p.xz).g; }
float random_yz(vec3 p) { return texture(random_texture, p.yz).b; }

float plaster_noise(vec3 p, float scale) 
{
	p *= scale;
	float xy = random_xy(p);
	float xz = random_xz(p);
	float yz = random_yz(p);
	yz = 0.0;
	xy = 0.0;
	return (xy + xz + yz) / 3.0;
}


void fragment() {
	float large_noise = plaster_noise(local_position, noise_scale);
	float fine_noise  = plaster_noise(local_position, fine_scale);

	float noise = (large_noise * 0.7) + (fine_noise * 0.3); // Combine the two scales.
	float color_offset = (noise - 0.5) * color_variation;

	ALBEDO = plaster_color + vec3(color_offset);
	//ALBEDO = vec3(color_offset);


	// --------------------------------------------------------
	// ROUGHNESS
	// --------------------------------------------------------

	ROUGHNESS =
		roughness +
		(noise - 0.5) * 0.08;


	// --------------------------------------------------------
	// BUMP
	// --------------------------------------------------------

	float bump =
		(fine_noise - 0.5) * bump_strength;

	//NORMAL_MAP = vec3(
	//	bump,
	//	bump,
	//	1.0
	//);
}