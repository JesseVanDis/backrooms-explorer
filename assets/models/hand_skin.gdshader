shader_type spatial;
render_mode sss_mode_skin, cull_back;


// ============================================================
// TEXTURES
// ============================================================

// Blender: Image Texture
// -> Normal Map (Strength 1.3)
// -> Bump
uniform sampler2D normal_texture : hint_normal;


// Blender: Image Texture.001
// -> Bright/Contrast
// -> RGB Curves
// -> Subsurface Scattering Color
uniform sampler2D skin_texture : source_color;


// Blender: Image Texture.002
// -> Mix.003
// -> Bright/Contrast.001
// -> Bump Height
uniform sampler2D height_texture;


// Blender: Image Texture.003
//
// THIS IS YOUR SPECULAR MAP.
//
// Black = 100% specular
// White = 0% specular
//
// Therefore it is inverted when used by Godot.
uniform sampler2D specular_map;


// ============================================================
// NORMAL MAP
// ============================================================

group_uniforms Normal;

uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;


// Flip the green channel if the normal map appears
// to be pointing in the wrong direction.
//
// Start with OFF.
uniform bool flip_normal_y = false;


// ============================================================
// BUMP
// ============================================================

uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;

uniform float bump_distance : hint_range(0.0, 1.0) = 0.1;


// ============================================================
// SKIN / SSS
// ============================================================

group_uniforms Skin;

uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.0;

uniform vec3 subsurface_color : source_color =
    vec3(1.0, 0.20, 0.12);

uniform float subsurface_depth : hint_range(0.01, 10.0) = 1.0;


// Blender Translucent BSDF approximation.
uniform float translucency : hint_range(0.0, 1.0) = 0.1;


// ============================================================
// SURFACE
// ============================================================

group_uniforms Surface;


// Global multiplier for the specular map.
uniform float specular_strength : hint_range(0.0, 1.0) = 0.22;


// Base roughness.
// This is exposed because the exact Blender Math node
// operation was not included in the export.
uniform float base_roughness : hint_range(0.0, 1.0) = 0.7;


// How much the specular map affects roughness.
//
// 0 = specular map does not affect roughness
// 1 = black specular areas become much smoother
uniform float specular_roughness_effect :
    hint_range(0.0, 1.0) = 0.5;


// ============================================================
// BRIGHT / CONTRAST
// ============================================================

vec3 apply_brightness_contrast(
    vec3 color,
    float brightness,
    float contrast
)
{
    color += brightness;

    color =
        (color - 0.5)
        * (1.0 + contrast)
        + 0.5;

    return clamp(color, 0.0, 1.0);
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
    // ========================================================
    // SAMPLE TEXTURES
    // ========================================================

    vec3 normal_tex =
        texture(normal_texture, UV).rgb;

    vec3 skin_tex =
        texture(skin_texture, UV).rgb;

    float height =
        texture(height_texture, UV).r;

    float specular_tex =
        texture(specular_map, UV).r;


    // ========================================================
    // SPECULAR MAP
    // ========================================================
    //
    // Your texture:
    //
    // BLACK  = 100% specular
    // WHITE  = 0% specular
    //
    // Therefore invert it.
    // ========================================================

    float specular_mask =
        1.0 - specular_tex;

    specular_mask =
        clamp(specular_mask, 0.0, 1.0);

    SPECULAR =
        specular_mask
        * specular_strength;


    // ========================================================
    // NORMAL MAP
    // ========================================================
    //
    // IMPORTANT:
    //
    // We do NOT manually convert the texture before assigning
    // it to NORMAL_MAP.
    //
    // Godot expects the normal-map texture representation here.
    // ========================================================

    if (flip_normal_y)
    {
        normal_tex.g =
            1.0 - normal_tex.g;
    }

    NORMAL_MAP =
        normal_tex;

    NORMAL_MAP_DEPTH =
        normal_strength;


    // ========================================================
    // BUMP
    // ========================================================
    //
    // Blender:
    //
    // Image Texture.002
    //        |
    //        +------ Image Texture.003
    //        |             |
    //        +---- Mix.003-+
    //                    |
    //              Bright/Contrast
    //                    |
    //                  Bump
    //
    // Exact Mix.003 operation is unavailable in the export,
    // so this is an approximation.
    // ========================================================

    float bump_height =
        mix(
            height,
            0.5,
            specular_tex
        );


    // Calculate height gradient.

    float height_dx =
        dFdx(bump_height);

    float height_dy =
        dFdy(bump_height);


    vec3 bump_normal =
        normalize(
            vec3(
                -height_dx
                * bump_strength
                * bump_distance,

                -height_dy
                * bump_strength
                * bump_distance,

                1.0
            )
        );


    // ========================================================
    // COMBINE NORMAL + BUMP
    // ========================================================

    vec3 tangent_normal =
        normal_tex * 2.0 - 1.0;

    tangent_normal.xy *=
        normal_strength;

    tangent_normal =
        normalize(tangent_normal);


    vec3 combined_normal =
        normalize(
            tangent_normal
            + bump_normal
            - vec3(0.0, 0.0, 1.0)
        );


    // Convert back to Godot's representation.

    NORMAL_MAP =
        combined_normal * 0.5 + 0.5;

    NORMAL_MAP_DEPTH =
        1.0;


    // ========================================================
    // SKIN COLOR
    // ========================================================
    //
    // Blender:
    //
    // Image Texture.001
    //        ↓
    // Bright/Contrast
    // Contrast = 0.05
    //        ↓
    // RGB Curves
    //        ↓
    // SSS Color
    //
    // RGB Curve data wasn't present in the export, so it
    // cannot yet be reproduced exactly.
    // ========================================================

    vec3 skin_color =
        apply_brightness_contrast(
            skin_tex,
            0.0,
            0.05
        );

    ALBEDO =
        skin_color;


    // ========================================================
    // ROUGHNESS
    // ========================================================
    //
    // We make the same black areas that are highly specular
    // somewhat smoother.
    //
    // This is an approximation of:
    //
    // Mix.001 -> Math -> Glossy Roughness
    // ========================================================

    float roughness_from_specular =
        mix(
            base_roughness,
            base_roughness * 0.45,
            specular_mask
            * specular_roughness_effect
        );

    ROUGHNESS =
        clamp(
            roughness_from_specular,
            0.0,
            1.0
        );


    // ========================================================
    // METALLIC
    // ========================================================

    METALLIC = 0.0;


    // ========================================================
    // SUBSURFACE SCATTERING
    // ========================================================
    //
    // Blender:
    //
    // Subsurface Scattering
    //
    // Scale     = 0.007
    // IOR       = 1.4
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
    // ========================================================
    //
    // Blender:
    //
    // Translucent BSDF
    //        ↓
    // Mix Shader
    //
    // BACKLIGHT provides a reasonable approximation in Godot.
    // ========================================================

    BACKLIGHT =
        subsurface_color
        * translucency;
}
