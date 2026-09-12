shader_type spatial;
render_mode sss_mode_skin, cull_back;

// ============================================================
// TEXTURES
// ============================================================

// Blender:
// Image Texture -> Normal Map -> Bump
//
// Import this as a NORMAL MAP texture in Godot.
uniform sampler2D normal_texture : hint_normal;

// Blender:
// Image Texture.001 -> Bright/Contrast -> RGB Curves
// -> Subsurface Scattering Color
uniform sampler2D skin_texture : source_color;

// Blender:
// Image Texture.002 -> Mix.003 -> Bump Height
uniform sampler2D height_texture;

// Blender:
// Image Texture.003
// Used as a mask in several Mix nodes.
uniform sampler2D mask_texture;


// ============================================================
// NORMAL / BUMP
// ============================================================

group_uniforms Normal;

uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;

uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;

uniform float bump_distance : hint_range(0.0, 1.0) = 0.1;

// Set this to 1 if the normal map's green channel needs
// to be inverted.
uniform bool flip_normal_y = false;


// ============================================================
// SKIN
// ============================================================

group_uniforms Skin;

uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.0;

uniform vec3 subsurface_color : source_color = vec3(1.0, 0.20, 0.12);

uniform float subsurface_depth : hint_range(0.01, 10.0) = 1.0;

uniform float translucency : hint_range(0.0, 1.0) = 0.1;


// ============================================================
// SPECULAR / ROUGHNESS
// ============================================================

group_uniforms Surface;

uniform float base_roughness : hint_range(0.0, 1.0) = 0.6;

uniform float specular_strength : hint_range(0.0, 1.0) = 0.5;


// ============================================================
// HELPER
// ============================================================

vec3 apply_brightness_contrast(
    vec3 color,
    float brightness,
    float contrast
) {
    color += brightness;

    color = (color - 0.5)
        * (1.0 + contrast)
        + 0.5;

    return clamp(color, 0.0, 1.0);
}


// ============================================================
// VERTEX
// ============================================================

void vertex()
{
    // Nothing required here.
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
    // ========================================================
    // SAMPLE TEXTURES
    // ========================================================

    vec3 normal_tex = texture(
        normal_texture,
        UV
    ).rgb;

    vec3 skin_tex = texture(
        skin_texture,
        UV
    ).rgb;

    float height = texture(
        height_texture,
        UV
    ).r;

    float mask = texture(
        mask_texture,
        UV
    ).r;


    // ========================================================
    // NORMAL MAP
    //
    // IMPORTANT:
    //
    // We do NOT do:
    //
    // normal_tex * 2.0 - 1.0
    //
    // Godot's NORMAL_MAP expects the texture representation.
    // ========================================================

    if (flip_normal_y)
    {
        normal_tex.g = 1.0 - normal_tex.g;
    }

    NORMAL_MAP = normal_tex;

    NORMAL_MAP_DEPTH = normal_strength;


    // ========================================================
    // BUMP
    //
    // Blender:
    //
    // Image Texture.002
    //        +
    // Image Texture.003
    //        ↓
    //      Mix.003
    //        ↓
    // Bright/Contrast.001
    //        ↓
    //      Bump
    //
    // Exact Blender Mix semantics are not present in the
    // exported node information, so this is an approximation.
    // ========================================================

    float bump_height = mix(
        height,
        0.5,
        mask
    );

    // Small screen-space height gradient.
    //
    // This creates a normal perturbation from the height map.
    float height_dx = dFdx(bump_height);
    float height_dy = dFdy(bump_height);

    vec3 bump_normal = normalize(
        vec3(
            -height_dx * bump_strength * bump_distance,
            -height_dy * bump_strength * bump_distance,
            1.0
        )
    );


    // ========================================================
    // COMBINE BUMP WITH NORMAL MAP
    // ========================================================
    //
    // Convert the normal texture into tangent-space vector
    // only for combining it with the bump.
    //
    // NORMAL_MAP itself above remains in the correct Godot
    // texture representation.
    // ========================================================

    vec3 tangent_normal =
        normal_tex * 2.0 - 1.0;

    tangent_normal.xy *= normal_strength;

    tangent_normal = normalize(tangent_normal);

    // Combine tangent-space normals.
    vec3 combined_normal = normalize(
        tangent_normal + bump_normal - vec3(0.0, 0.0, 1.0)
    );

    // Convert back to Godot's normal-map representation.
    NORMAL_MAP =
        combined_normal * 0.5 + 0.5;

    NORMAL_MAP_DEPTH = 1.0;


    // ========================================================
    // SKIN COLOR
    //
    // Blender:
    //
    // Image Texture.001
    //       ↓
    // Bright/Contrast
    //       ↓
    // RGB Curves
    //       ↓
    // Subsurface Scattering
    //
    // The RGB Curve points weren't included in the export,
    // so only the Bright/Contrast portion is reproduced here.
    // ========================================================

    vec3 skin_color =
        apply_brightness_contrast(
            skin_tex,
            0.0,
            0.05
        );

    ALBEDO = skin_color;


    // ========================================================
    // ROUGHNESS
    // ========================================================
    //
    // Blender:
    //
    // Mix.001 -> Math -> Glossy Roughness
    //
    // The exact Math operation wasn't exported, so this is
    // exposed as a parameter for now.
    // ========================================================

    ROUGHNESS = base_roughness;


    // ========================================================
    // SPECULAR
    // ========================================================

    SPECULAR = specular_strength;


    // ========================================================
    // METALLIC
    // ========================================================

    METALLIC = 0.0;


    // ========================================================
    // SUBSURFACE SCATTERING
    //
    // Blender:
    //
    // Subsurface Scattering
    // Scale = 0.007
    // IOR = 1.4
    // Roughness = 1.0
    // ========================================================

    SSS_STRENGTH =
        subsurface_strength;

    SSS_TRANSMITTANCE_COLOR =
        vec4(
            subsurface_color,
            1.0
        );

    SSS_TRANSMITTANCE_DEPTH =
        subsurface_depth;

    SSS_TRANSMITTANCE_BOOST =
        0.0;


    // ========================================================
    // TRANSLUCENCY
    //
    // Blender:
    //
    // Translucent BSDF
    //        ↓
    // Mix Shader
    //
    // BACKLIGHT is the closest simple Godot equivalent.
    // ========================================================

    BACKLIGHT =
        subsurface_color
        * translucency;
}