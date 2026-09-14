shader_type spatial;

varying float y_pos;

void vertex() {
	y_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float factor = clamp((y_pos * 0.1) + 1.0, 0.0, 1.0);
	ALBEDO = mix(vec3(0.0), vec3(0.3), factor);
	SPECULAR = 0.0;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
