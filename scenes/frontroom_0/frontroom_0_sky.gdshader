shader_type sky;

uniform vec3 skyColor : source_color;
uniform vec3 horizonColor : source_color;
uniform float sunEnergyMultiplier = 1.0;

const float sunRadius = 0.050;


void sky() {
	// sky
	vec3 sky_color = mix(horizonColor, skyColor, clamp(EYEDIR.y * 2.0, 0, 1));
	
	// sun
	float sun = 1.0 - min(1.0, (length(EYEDIR - LIGHT0_DIRECTION)));
	vec3 sunColor = vec3(clamp(0, sunEnergyMultiplier, pow((sun + sunRadius), 100.0)));
	//vec3 sunColor = vec3(clamp((((sun - 1.0) + sunRadius) * 40.0), 0.0, 1.0));
	
	COLOR = sky_color + sunColor;
	// COLOR = sky_color * LIGHT0_ENERGY;
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
}
