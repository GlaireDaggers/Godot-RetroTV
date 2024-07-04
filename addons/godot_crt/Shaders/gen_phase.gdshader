shader_type canvas_item;

uniform float screen_height;	// height of output LUT
uniform float hz;				// screen refresh rate
uniform float pps;				// phase offset per scanline
uniform float ppf;				// phase offset per frame

void fragment() {
	float fr = (TIME * hz);
	float t1 = (fr + 1.0) / hz;
	float t2 = fr / hz;
	
	float y = SCREEN_UV.y * screen_height;
	float phase = (ppf * t1 * hz) + (pps * y);
	float prev_phase = (ppf * t2 * hz) + (pps * y);
	
	COLOR = vec4(mod(phase, 1.0), mod(prev_phase, 1.0), 0.0, 1.0);
}