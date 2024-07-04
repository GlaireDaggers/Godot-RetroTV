shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float sharpen_resolution;
uniform float sharpen_amount;

void fragment() {
	float neighbor = sharpen_amount * -1.0;
	float center = sharpen_amount * 2.0 + 1.0;
	
	vec2 offset = vec2(1.0 / sharpen_resolution, 0.0);
	
	vec3 rgb = textureLod(screen_texture, SCREEN_UV - offset, 0.0).rgb * neighbor +
		textureLod(screen_texture, SCREEN_UV, 0.0).rgb * center +
		textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb * neighbor;
	
	COLOR = vec4(rgb, 1.0);
}