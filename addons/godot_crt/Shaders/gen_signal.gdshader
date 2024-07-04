shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_enable;

uniform bool svideo;
uniform float noise_amount;
uniform float vsync_offset;
uniform float c;					// carrier wavelength
uniform vec2 output_resolution;
uniform sampler2D cb_lut;

uniform sampler2D hsync_lut : filter_nearest, repeat_enable;

vec3 rgb2yiq(vec3 rgb) {
	float y = 0.30 * rgb.r + 0.59 * rgb.g + 0.11 * rgb.b;
	float i = (-0.27 * (rgb.b - y)) + (0.74 * (rgb.r - y));
	float q = (0.41 * (rgb.b - y)) + (0.48 * (rgb.r - y));
	
	return vec3(y, i, q);
}

float rand(vec2 co){ return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px_coord = output_resolution * uv;
	
	// sample rgb
	float hsync_offset = textureLod(hsync_lut, vec2(0.0, (SCREEN_UV.y + (11.0 / 262.0)) * (1.0 - (11.0 / 262.0))), 0.0).r; // rand(vec2(mod(TIME, 1.0), SCREEN_UV.y)) - 0.5;
	vec2 src_uv = uv + vec2(hsync_offset, vsync_offset);
	// we wrap src_uv at a slightly-larger-than-1.0 boundary
	// this basically gives us the "rolling" effect while also preserving a small black boundary
	// (which would be the hblank/vblank portion of the signal)
	src_uv.x = mod(src_uv.x, 1.17);
	src_uv.y = mod(src_uv.y, 1.0 + (11.0 / 262.0));
	vec3 rgb = textureLod(screen_texture, src_uv, 0.0).rgb
		* step(0.0, src_uv.x)
		* step(src_uv.x, 1.0)
		* step(0.0, src_uv.y)
		* step(src_uv.y, 1.0);
	
	// convert to yiq
	vec3 yiq = rgb2yiq(rgb);
	
	// colorburst
	vec2 phase = textureLod(cb_lut, vec2(0.0, uv.y), 0.0).rg;
	float carrier1 = sin(2.0 * PI * (phase.x + px_coord.x / c));
	float carrier2 = sin(2.0 * PI * (phase.y + px_coord.x / c));
	float quadrature1 = -cos(2.0 * PI * (phase.x + px_coord.x / c));
	float quadrature2 = -cos(2.0 * PI * (phase.y + px_coord.x / c));
	
	// sample noise
	float noise = (rand(SCREEN_UV + mod(TIME, 1.0)) * 2.0 - 1.0) * noise_amount;
	
	float luma = yiq.x;
	float chroma1 = carrier1 * yiq.y + quadrature1 * yiq.z;
	float chroma2 = carrier2 * yiq.y + quadrature2 * yiq.z;
	
	if (svideo) {
		float signal1 = chroma1 + noise;
		float signal2 = chroma2 + noise;
		
		COLOR = vec4(luma + noise, signal1 * 0.5 + 0.5, signal2 * 0.5 + 0.5, 1.0);
	}
	else {
		float signal1 = (luma + chroma1) + noise;
		float signal2 = (luma + chroma2) + noise;
		
		COLOR = vec4(0.0, signal1 * 0.5 + 0.5, signal2 * 0.5 + 0.5, 1.0);
	}
}