shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.38, 0.33, 0.19);
uniform float color_fade: hint_range(-2.0, 8.0) = 0.6;
uniform highp vec3 skew = vec3(3.0, 0.4, -1.73);
uniform float height: hint_range(0.001, 1.0) = 0.03;
uniform float min_height: hint_range(-1.0, 1.0) = 0.3;

varying float height_perc;

void vertex() {
    height_perc = VERTEX.y;
	VERTEX.y = VERTEX.y * height;
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float pseudo_random_2d(highp vec2 p)
{
	highp float h1x = 12.9989;
	highp float h1y = 13.1536;
	highp float h2 = 43758.54;
	return fract(sin(dot(p, vec2(h1x, h1y))) * h2);
}

float curve(float x, float k)
{
	return ((1.0/-(x+k)) * k + 1.0) * (k+1.0);
}

void fragment() {
	
	highp vec2 cells = UV * vec2(1000.0, 1000.0);
	cells += skew.xy * curve(height_perc, skew.z);
	highp vec2 cell_id = floor(cells);
	highp vec2 cell_uv = cells - cell_id;
	

	float cell_total_height = mix(min_height, 1.0, pseudo_random_2d(cell_id));
	float distance_from_top = cell_total_height - height_perc;
	float top_cutoff = min(1.0, curve(distance_from_top * 0.6, 0.05));

	vec2 cell_normal = (cell_uv * 2.0) - 1.0;
	float cell_dist_sq_from_center_2d = dot(cell_normal, cell_normal);
	
	float alpha = height_perc;
	if (cell_dist_sq_from_center_2d > top_cutoff * 1.6)
	{
		alpha = 1.0;
	}
	
	vec3 color = base_color * (vec3(mix(1.0, 1.0 + color_fade, height_perc)));// * rand;
	ALBEDO = color;
	//ALBEDO = vec3(0.0, 0.0, top_cutoff);
	ALPHA = cell_total_height;
	ALPHA_SCISSOR_THRESHOLD = alpha;
}