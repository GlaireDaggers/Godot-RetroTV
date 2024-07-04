shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;

uniform bool svideo;
uniform int c;					// carrier wavelength
uniform vec2 output_resolution;

void fragment() {
	float luma = 0.0;
	
	// run a simple box filter over carrier wavelength to get luma from input
	for (int i = 0; i < c; i++) {
		vec2 offs = SCREEN_UV + vec2(float(i) / output_resolution.x, 0.0);
		vec2 sig = textureLod(screen_texture, offs, 0.0).gb * 2.0 - 1.0;
		luma += sig.x;
	}
	
	luma /= float(c);
	
	// subtract extracted luma from signal to get chroma
	vec2 chr = (textureLod(screen_texture, SCREEN_UV, 0.0).gb * 2.0 - 1.0) - luma;
	
	// returning three channels - one with luma, and two with cur+prev chroma
	COLOR = vec4(luma, chr * 0.5 + 0.5, 1.0);
}