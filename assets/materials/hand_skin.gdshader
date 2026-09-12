shader_type spatial;
render_mode sss_mode_skin, cull_back, depth_draw_always;

uniform sampler2D normal_texture : hint_normal;
uniform sampler2D skin_texture : source_color;
uniform sampler2D alpha_texture : source_color;
uniform sampler2D height_texture;
uniform sampler2D specular_map;  // Black = 100% specular, White = 0% specular

group_uniforms Normal;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
uniform bool flip_normal_y = false;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;
uniform float bump_distance : hint_range(0.0, 1.0) = 0.1;

group_uniforms Skin;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 subsurface_color : source_color = vec3(1.0, 0.20, 0.12);
uniform float subsurface_depth : hint_range(0.01, 10.0) = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.1;

group_uniforms Surface;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.22;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.7;
uniform float specular_roughness_effect : hint_range(0.0, 1.0) = 0.5;  // 0 = specular map does not affect roughness, 1 = black specular areas become much smoother

vec3 apply_brightness_contrast(vec3 color, float brightness, float contrast) {
	color += brightness;
	color = (color - 0.5) * (1.0 + contrast) + 0.5;
	return clamp(color, 0.0, 1.0);
}

void fragment() {
	vec3 normal_tex = texture(normal_texture, UV).rgb;
	vec3 skin_tex = texture(skin_texture, UV).rgb;
	float alpha = texture(alpha_texture, UV).r;
	float height = texture(height_texture, UV).r;
	float specular_tex = texture(specular_map, UV).r;

	float specular_mask = clamp(1.0 - specular_tex, 0.0, 1.0);
	SPECULAR = specular_mask * specular_strength;

	if (flip_normal_y) {
		normal_tex.g = 1.0 - normal_tex.g;
	}

	NORMAL_MAP = normal_tex;
	NORMAL_MAP_DEPTH = normal_strength;

	float bump_height = mix(height, 0.5, specular_tex);
	float height_dx = dFdx(bump_height);
	float height_dy = dFdy(bump_height);

	vec3 bump_normal = normalize(vec3(-height_dx * bump_strength * bump_distance, -height_dy * bump_strength * bump_distance, 1.0));

	vec3 tangent_normal = normal_tex * 2.0 - 1.0;
	tangent_normal.xy *= normal_strength;
	tangent_normal = normalize(tangent_normal);

	vec3 combined_normal = normalize(tangent_normal + bump_normal - vec3(0.0, 0.0, 1.0));

	NORMAL_MAP = combined_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	vec3 skin_color = apply_brightness_contrast(skin_tex, 0.0, 0.05);
	ALBEDO = skin_color;

	float roughness_from_specular = mix(base_roughness, base_roughness * 0.45, specular_mask * specular_roughness_effect);
	ROUGHNESS = clamp(roughness_from_specular, 0.0, 1.0);

	METALLIC = 0.0;

	SSS_STRENGTH = subsurface_strength;
	SSS_TRANSMITTANCE_COLOR = vec4(subsurface_color, 1.0);
	SSS_TRANSMITTANCE_DEPTH = subsurface_depth;
	SSS_TRANSMITTANCE_BOOST = 0.0;

	// BACKLIGHT provides a reasonable approximation of Translucent BSDF in Godot.
	BACKLIGHT = subsurface_color * translucency;
	ALPHA = alpha;
}
