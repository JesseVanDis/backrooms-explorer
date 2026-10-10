shader_type canvas_item;

uniform float temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float tint : hint_range(-1.0, 1.0) = 0.0;
uniform float color_boost : hint_range(0.0, 2.0) = 0.0;

vec3 apply_white_balance(vec3 color, float temp, float tint_shift) {
    // Temperature: positive = warmer, negative = cooler
    color.r += temp * 0.1;
    color.b -= temp * 0.1;

    // Tint: positive = magenta, negative = green
    color.r += tint_shift * 0.05;
    color.b += tint_shift * 0.05;
    color.g -= tint_shift * 0.05;

    return clamp(color, vec3(0.0), vec3(1.0));
}

// Color boost: enhance less-saturated colors more strongly
vec3 apply_color_boost(vec3 color, float boost) {
    float max_channel = max(color.r, max(color.g, color.b));
    float min_channel = min(color.r, min(color.g, color.b));

    float saturation = max_channel - min_channel;

    // Boost colors inversely to their existing saturation
    float amount = boost * (1.0 - saturation);

    float luminance = dot(color, vec3(0.299, 0.587, 0.114));

    return clamp(
        mix(vec3(luminance), color, 1.0 + amount),
        vec3(0.0),
        vec3(1.0)
    );
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    color.rgb = apply_white_balance(color.rgb, temperature, tint);
    color.rgb = apply_color_boost(color.rgb, color_boost);

    COLOR = color;
}