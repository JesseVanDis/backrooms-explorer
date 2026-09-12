shader_type spatial;
render_mode sss_mode_skin, cull_back;

// ============================================================
// TEXTURES
// ============================================================

// Image Texture
// Blender: Image Texture -> Normal Map
uniform sampler2D normal_texture : hint_normal;

// Image Texture.001
// Used for the skin/subsurface color chain.
uniform sampler2D skin_texture : source_color;

// Image Texture.002
// Used for bump/height information.
uniform sampler2D height_texture;

// Image Texture.003
// Used as the main mask for several Mix nodes.
uniform sampler2D mask_texture : source_color;


// ============================================================
// CONTROLS
// ============================================================

group_uniforms Surface;

uniform float normal_strength : hint_range(0.0, 3.0) = 1.3;

uniform float bump_strength : hint_range(0.0, 1.0) = 0.15;
uniform float bump_distance : hint_range(0.0, 1.0) = 0.1;

uniform float roughness : hint_range(0.0, 1.0) = 0.35;

uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.7;

uniform vec3 subsurface_color : source_color =
    vec3(1.0, 0.25, 0.18);

uniform float subsurface_depth : hint_range(0.0, 10.0) = 1.0;

uniform float translucency : hint_range(0.0, 1.0) = 0.1;


// ============================================================
// HELPERS
// ============================================================

// Approximation of Blender Bright/Contrast.
//
// Blender's Bright/Contrast node is not exactly equivalent to
// this simple operation, but this gives a useful approximation.
vec3 bright_contrast(vec3 color, float brightness, float contrast)
{
    color += brightness;

    color = (color - 0.5) * (1.0 + contrast) + 0.5;

    return color;
}


// ============================================================
// FRAGMENT
// ============================================================

void fragment()
{
    // --------------------------------------------------------
    // TEXTURES
    // --------------------------------------------------------

    vec4 skin_tex = texture(skin_texture, UV);
    vec4 normal_tex = texture(normal_texture, UV);
    vec4 height_tex = texture(height_texture, UV);
    vec4 mask_tex = texture(mask_texture, UV);


    // --------------------------------------------------------
    // NORMAL MAP
    //
    // Blender:
    //
    // Image Texture
    //      ↓
    // Normal Map (Strength 1.3)
    //      ↓
    // Bump
    // --------------------------------------------------------

    vec3 normal_map = normal_tex.rgb * 2.0 - 1.0;

    // Apply normal strength.
    normal_map.xy *= normal_strength;

    NORMAL_MAP = normalize(normal_map);
    NORMAL_MAP_DEPTH = normal_strength;


    // --------------------------------------------------------
    // BUMP
    //
    // Blender:
    //
    // Image Texture.002
    //       +
    // Image Texture.003
    //       ↓
    // Mix.003
    //       ↓
    // Bump
    //
    // The exact Blender Mix operation is ambiguous in the
    // exported data, so this is an approximation.
    // --------------------------------------------------------

    float height = height_tex.r;

    float mask = mask_tex.r;

    height = mix(
        height,
        0.5,
        mask
    );

    // Convert height variation into a subtle normal effect.
    float dx = dFdx(height);
    float dy = dFdy(height);

    vec3 bump_normal = normalize(
        vec3(
            -dx * bump_distance * bump_strength,
            -dy * bump_distance * bump_strength,
            1.0
        )
    );

    // Combine with normal map.
    NORMAL_MAP = normalize(
        NORMAL_MAP + bump_normal - vec3(0.0, 0.0, 1.0)
    );


    // --------------------------------------------------------
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
    // Subsurface Scattering Color
    // --------------------------------------------------------

    vec3 skin_color = skin_tex.rgb;

    skin_color = bright_contrast(
        skin_color,
        0.0,
        0.05
    );

    ALBEDO = skin_color;


    // --------------------------------------------------------
    // GLOSSY / SPECULAR
    //
    // Blender:
    //
    // Mix.002
    //       ↓
    // Glossy BSDF Color
    //
    // Math
    //       ↓
    // Glossy BSDF Roughness
    // --------------------------------------------------------

    // Approximation of the Blender glossy color mix.
    vec3 glossy_color = mix(
        vec3(0.3092, 0.3605, 0.3897),
        vec3(0.7883, 0.9230, 1.0),
        mask
    );

    SPECULAR = 0.5;

    ROUGHNESS = roughness;


    // --------------------------------------------------------
    // SUBSURFACE SCATTERING
    //
    // Blender:
    //
    // Subsurface Scattering
    //
    // Scale = 0.007
    // IOR = 1.4
    // Roughness = 1.0
    // --------------------------------------------------------

    SSS_STRENGTH = subsurface_strength;

    SSS_TRANSMITTANCE_COLOR =
        vec4(subsurface_color, 1.0);

    SSS_TRANSMITTANCE_DEPTH =
        subsurface_depth;

    SSS_TRANSMITTANCE_BOOST =
        0.0;


    // --------------------------------------------------------
    // BACKLIGHT / TRANSLUCENCY
    //
    // Blender also has:
    //
    // Translucent BSDF
    //       ↓
    // Mix Shader
    //
    // Godot's BACKLIGHT is a good approximation for this
    // particular use case.
    // --------------------------------------------------------

    BACKLIGHT =
        subsurface_color * translucency;


    // --------------------------------------------------------
    // FINAL
    // --------------------------------------------------------

    METALLIC = 0.0;
}
