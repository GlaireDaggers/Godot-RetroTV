shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D border_texture : repeat_disable, filter_linear;
uniform sampler2D mask_texture : repeat_enable, filter_linear_mipmap_anisotropic;

uniform vec2 scale;
uniform vec2 fisheye_intensity;
uniform vec2 mask_scale;
uniform float mask_intensity;
uniform float scanline_intensity;
uniform float brightness;

void fragment() {
	// fisheye
	vec2 uv = UV * 2.0 - 1.0;
	uv *= scale;
	
	vec2 center_uv;
	center_uv.x = (1.0 - uv.y * uv.y) * fisheye_intensity.x * uv.x;
	center_uv.y = (1.0 - uv.x * uv.x) * fisheye_intensity.y * uv.y;
	
	vec2 screen_uv = (uv - center_uv) * 0.5 + 0.5;
	
	float scan_phase = screen_uv.y * 480.0 * PI;
	float scan = sin(scan_phase) * 0.5 + 0.5;
	
	vec3 rgb = textureLod(screen_texture, screen_uv, 0.0).rgb;
	vec4 border = textureLod(border_texture, screen_uv, 0.0);
	rgb = mix(rgb, border.rgb, border.a);
	vec3 mask = texture(mask_texture, screen_uv * mask_scale).rgb;
	rgb *= mix(mask, vec3(1.0, 1.0, 1.0), 1.0 - mask_intensity);
	rgb *= mix(scan, 1.0, 1.0 - scanline_intensity);
	rgb *= brightness;
	COLOR = vec4(rgb, 1.0);
}