shader_type canvas_item;
render_mode unshaded;

// Main-menu key art. The live portrait is a duplicate of the Friend standing
// against the basement wall, with the head removed and the neck wound visible.
// The shader does the final grade: the left edge is sunk into black so the menu
// copy always reads, while the figure keeps a cold rim and a red emergency pulse.

uniform sampler2D portrait : hint_default_black, repeat_disable, filter_linear;
uniform vec2 image_size = vec2(1920.0, 1080.0);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float zoom : hint_range(0.9, 1.15) = 1.035;
uniform float left_fade : hint_range(0.0, 1.0) = 0.30;
uniform float grain_amount : hint_range(0.0, 0.08) = 0.016;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 cool_tint : source_color = vec4(0.68, 0.88, 0.86, 1.0);
uniform vec4 warm_tint : source_color = vec4(1.04, 0.91, 0.74, 1.0);
uniform vec4 red_color : source_color = vec4(0.72, 0.035, 0.012, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		vec2 i2 = floor(p);
		vec2 f = fract(p);
		f = f * f * (3.0 - 2.0 * f);
		float a = hash12(i2);
		float b = hash12(i2 + vec2(1.0, 0.0));
		float c = hash12(i2 + vec2(0.0, 1.0));
		float d = hash12(i2 + vec2(1.0, 1.0));
		v += mix(mix(a, b, f.x), mix(c, d, f.x), f.y) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

vec2 cover_uv(vec2 uv) {
	float screen_aspect = screen_size.x / max(screen_size.y, 1.0);
	float image_aspect = image_size.x / max(image_size.y, 1.0);
	vec2 scale = vec2(1.0);
	if (screen_aspect > image_aspect) {
		scale = vec2(screen_aspect / image_aspect, 1.0);
	} else {
		scale = vec2(1.0, image_aspect / screen_aspect);
	}
	// The tiny zoom keeps the still alive during the slow menu breathing.
	return (uv - vec2(0.5)) / zoom * scale + vec2(0.5);
}

void fragment() {
	vec2 uv = UV;
	vec2 tex_uv = cover_uv(uv);

	// A barely perceptible drift, like a camera operator trying not to move.
	tex_uv += vec2(sin(TIME * 0.075) * 0.0012, cos(TIME * 0.061) * 0.0016);
	vec3 col = texture(portrait, tex_uv).rgb;

	// Do not let the menu become a bright photograph. Keep the image in the
	// same near-black register as the game, then separate the figure with a
	// cool rim and dirty amber practicals.
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float blood_mask = smoothstep(0.06, 0.30, col.r - max(col.g, col.b));
	col = mix(col, vec3(luma), 0.22);
	col = max((col - 0.125) * 1.08 + 0.125, vec3(0.0));
	vec3 tint = mix(cool_tint.rgb, warm_tint.rgb, smoothstep(0.04, 0.72, luma));
	col *= mix(vec3(1.0), tint, 0.34);
	col *= 0.90;

	// Deliberate editorial falloff: the title and buttons live in this dark
	// left third, while the subject remains readable on the right.
	float left = smoothstep(0.0, left_fade, uv.x);
	col *= mix(0.085, 1.0, left);

	// A hint of flickering red at the frame edge, never enough to light the UI.
	// Blood and the neck wound need to survive the dark grade. Lift only the
	// pixels that are already strongly red so the concrete stays cold.
	// Keep the blood readable through the dark grade. The wall splatter is a
	// deliberate story beat, not a subtle colour accent.
	col.r = max(col.r, blood_mask * 0.38);
	col.g *= 1.0 - blood_mask * 0.18;
	col *= 1.0 + blood_mask * 0.20;

	float pulse = 0.55 + 0.45 * sin(TIME * 1.15 + sin(TIME * 0.27) * 2.2);
	col += red_color.rgb * smoothstep(0.70, 1.0, uv.x) * (1.0 - smoothstep(0.22, 0.80, uv.y)) * 0.020 * pulse;

	// Uneven lens dirt / breath on the glass.
	float haze = fbm(uv * vec2(3.8, 2.2) + vec2(TIME * 0.010, -TIME * 0.006));
	col *= 0.88 + haze * 0.12;

	// Deep vignette; the image should feel pressed into the dark.
	vec2 v = uv - vec2(0.52, 0.48);
	float vig = smoothstep(0.30, 0.95, length(v) * 1.28);
	col *= 1.0 - vig * vignette_strength;

	// Fine, monochrome sensor grain. No colour speckle.
	float grain = hash12(uv * vec2(1920.0, 1080.0) + vec2(TIME * 29.0, -TIME * 17.0)) - 0.5;
	col += grain * grain_amount;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
