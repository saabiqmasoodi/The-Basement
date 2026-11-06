shader_type canvas_item;
render_mode unshaded;

// Frosted-glass backdrop for the pause menu: a wide Gaussian blur of the
// frozen frame, darkened and tinted so the menu panel reads clearly.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_radius : hint_range(0.0, 6.0) = 2.4;
uniform float dim : hint_range(0.0, 1.0) = 0.58;
uniform vec4 tint : source_color = vec4(0.012, 0.014, 0.020, 1.0);
uniform float saturation_boost : hint_range(0.0, 1.0) = 0.15;

const float W[5] = float[](0.0625, 0.25, 0.375, 0.25, 0.0625);

void fragment() {
	vec2 step_px = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 col = vec3(0.0);
	float total = 0.0;

	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float w = W[x + 2] * W[y + 2];
			col += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_px).rgb * w;
			total += w;
		}
	}
	col /= total;

	// Keep the frozen scene just colourful enough to be recognisable.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.0 + saturation_boost);

	col = mix(col, tint.rgb, dim);
	COLOR = vec4(col, 1.0);
}
