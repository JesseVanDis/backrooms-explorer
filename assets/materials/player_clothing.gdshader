shader_type spatial;
// render_mode depth_draw_always;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;

void fragment() {
	vec2 uv = UV;
	vec4 albedo = texture(albedo_texture, UV);
	vec2 uv2_normalized = mix(vec2(-1.0), vec2(1.0), UV2);
	float uv2_x_dist = abs(uv2_normalized.x);
	float alpha_x = mix(-5.0, 12.0, uv2_x_dist);
	float alpha_y = (0.5 - uv2_normalized.y) * 0.75;
	float alpha = max(alpha_x, alpha_y);
	//alpha = (0.5 - uv2_normalized.y) * 2.0;

// continue here!
	if (alpha > 0.8)
	{
		discard;
	}

	vec3 final_color = base_color.rgb;
	final_color *= albedo.xyz;

	ALBEDO = final_color;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	// NORMAL = vec3(0,0,1);
	//ALPHA = clamp(alpha * albedo.w, 0.0, 1.0);
	// ALBEDO = vec3(alpha);
}