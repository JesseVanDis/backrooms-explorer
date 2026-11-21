shader_type spatial;
// render_mode depth_draw_always;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;

void fragment() {
	vec2 uv = UV;
	vec4 albedo = texture(albedo_texture, UV);

	vec3 final_color = base_color.rgb;
	final_color *= albedo.xyz;

	ALBEDO = final_color;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	// NORMAL = vec3(0,0,1);
	// ALBEDO = vec3(alpha);
}