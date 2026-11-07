shader_type canvas_item;
render_mode unshaded;

// Restrained main-menu backdrop: a cool, near-black gradient with a faint
// ember pool low in the frame, a slow breathing flicker, film grain and a
// cinematic vignette. It deliberately stays dim so the title and buttons own
// the composition.

uniform vec4 top_color : source_color = vec4(0.018, 0.022, 0.030, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.032, 0.027, 0.024, 1.0);
uniform vec4 ember_color : source_color = vec4(0.22, 0.075, 0.045, 1.0);
uniform float ember_strength : hint_range(0.0, 1.0) = 0.26;
uniform float grain_amount : hint_range(0.0, 0.08) = 0.016;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.62;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	vec2 p = uv - vec2(0.5, 0.66);
	p.x *= 1.4;
	float ember = smoothstep(0.52, 0.0, length(p));
	float flicker = 0.92 + 0.08 * sin(TIME * 0.7 + sin(TIME * 0.23) * 2.0);
	col += ember_color.rgb * ember * ember_strength * flicker;

	// A faint warm halo behind the title, kept well below the letters.
	vec2 tp = uv - vec2(0.5, 0.17);
	tp.x *= 1.5;
	float title_glow = smoothstep(0.30, 0.0, length(tp));
	col += ember_color.rgb * title_glow * 0.12 * flicker;

	vec2 v = uv - 0.5;
	float vig = 1.0 - smoothstep(0.35, 0.9, length(v) * 1.35) * vignette_strength;
	col *= vig;

	float grain = hash12(uv * vec2(1920.0, 1080.0) + vec2(TIME * 31.0, -TIME * 17.0)) - 0.5;
	col += grain * grain_amount;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
