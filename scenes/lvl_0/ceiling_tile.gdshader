shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0);

uniform sampler2D noise_texture : source_color;

uniform float edge_thickness : hint_range(0.0, 1.0) = 0.2;
uniform float noise_strength : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.0, 10.0) = 1.0;

uniform float bump_thickness : hint_range(0.0, 0.05) = 0.01;
uniform float bump : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	
	// UV0 = noise texture
	vec4 noise = texture(noise_texture, UV * noise_scale);

	float h = (UV.x - 0.5) * 2.0;
	float v = (UV.y - 0.5) * 2.0;

	float h_dist = abs(h);
	float v_dist = abs(v);
	
	float is_edge = max(max(0, step(1.0 - edge_thickness, h_dist)), step(1.0 - edge_thickness, v_dist));
	
	float is_on_edge_px = -step(abs((1.0 - edge_thickness) - h), bump_thickness);
	float is_on_edge_nx =  step(abs((1.0 - edge_thickness) + h), bump_thickness);
	float is_on_edge_py =  step(abs((1.0 - edge_thickness) - v), bump_thickness);
	float is_on_edge_ny = -step(abs((1.0 - edge_thickness) + v), bump_thickness);
	
	if(is_edge > 0.0)
	{
		is_on_edge_px = 0.0;
		is_on_edge_nx = 0.0;
		is_on_edge_py = 0.0;
		is_on_edge_ny = 0.0;
	}
	
	//// Convert black/white noise to a usable mask.
	float noise_mask = mix(noise.r, 0.0, is_edge);
//
	//// Start with the base color and blend the pattern over it.
	vec3 final_color = mix(
		base_color.rgb,
		edge_color.rgb,
		is_edge
	);
	
	final_color *= 1.0 - (noise_mask * noise_strength);
	
	vec3 normal = normalize(vec3((is_on_edge_px + is_on_edge_nx) * bump, (is_on_edge_py + is_on_edge_ny) * bump, -1.0));
	
	NORMAL_MAP = normal * 0.5 + 0.5;
	
	//ALBEDO = normal;
	ALBEDO = final_color;
	
	SPECULAR = mix(0.0, 0.7, is_edge);
	ROUGHNESS = mix(1.0, 0.75, is_edge);
	METALLIC = mix(0.0, 0.0, is_edge);
	
}