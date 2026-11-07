shader_type canvas_item;
render_mode unshaded;

// Subtle horror grade applied on top of the 3D view:
//   * desaturated, cool shadows / warm highlights
//   * cinematic vignette
//   * fine animated film grain
//   * a whisper of chromatic aberration
// The amounts are intentionally restrained so the game stays readable.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.46;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.4;
uniform float grain_amount : hint_range(0.0, 0.12) = 0.022;
uniform float grain_speed : hint_range(0.0, 120.0) = 37.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.12;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.28;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0007;
uniform vec3 shadow_tint : source_color = vec3(0.70, 0.81, 1.0);
uniform vec3 highlight_tint : source_color = vec3(1.05, 0.98, 0.90);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Very slight lens fringe toward the edges.
	vec2 dir = uv - vec2(0.5);
	float edge = dot(dir, dir);
	vec3 col;
	col.r = texture(screen_texture, uv + dir * chromatic_aberration * edge).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - dir * chromatic_aberration * edge).b;

	// Cinematic colour grade.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturation);
	vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.12, 0.86, luma));
	col *= mix(vec3(1.0), tint, tint_amount);

	// Vignette.
	float d = distance(uv, vec2(0.5)) * 1.41421356;
	float vig = smoothstep(vignette_start, 1.0, d);
	col *= 1.0 - vig * vignette_strength;

	// Animated film grain (monochrome, screen-space).
	float n = hash12(uv * vec2(1920.0, 1080.0) + vec2(TIME * grain_speed, TIME * grain_speed * 0.71));
	col += (n - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
