shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float c;					// carrier wavelength
uniform vec2 output_resolution;
uniform sampler2D cb_lut;

uniform bool temporal_blend;

vec3 yiq2rgb(vec3 yiq) {
	float r = yiq.x + 0.9469 * yiq.y + 0.6236 * yiq.z;
	float g = yiq.x - 0.2748 * yiq.y - 0.6357 * yiq.z;
	float b = yiq.x - 1.1000 * yiq.y + 1.7000 * yiq.z;
	
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px_coord = output_resolution * SCREEN_UV;
	
	float y = textureLod(screen_texture, SCREEN_UV, 0.0).r;
	
	float i, q;
	i = 0.0;
	q = 0.0;
	
	// colorburst phase
	vec2 phase = textureLod(cb_lut, vec2(0.0, uv.y), 0.0).rg;
	
	// run a simple box filter over carrier wavelength to extract i/q
	for (float j = 0.0; j < c; j++) {
		vec2 offs = SCREEN_UV + vec2(j / output_resolution.x);
		float x = px_coord.x + j;
		
		// colorburst
		float carrier1 = sin(2.0 * PI * (phase.x + x / c));
		float carrier2 = sin(2.0 * PI * (phase.y + x / c));
		float quadrature1 = -cos(2.0 * PI * (phase.x + x / c));
		float quadrature2 = -cos(2.0 * PI * (phase.y + x / c));
		
		vec2 smp = textureLod(screen_texture, offs, 0.0).gb * 2.0 - 1.0;
		
		float i1 = smp.x * carrier1;
		float i2 = smp.y * carrier2;
		
		float q1 = smp.x * quadrature1;
		float q2 = smp.y * quadrature2;
		
		if (temporal_blend) {
			i += (i1 + i2) * 0.5;
			q += (q1 + q2) * 0.5;
		}
		else {
			i += i1;
			q += q1;
		}
	}
	
	i /= c;
	q /= c;
	
	// convert back to rgb
	vec3 rgb = yiq2rgb(vec3(y, i, q));
	
	COLOR = vec4(rgb, 1.0);
}