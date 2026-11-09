shader_type canvas_item;
render_mode unshaded;

// Main-menu backdrop: a cold, near-black service corridor.
// A sickly doorway glow and a distant red emergency strip are the only light
// sources. A figure stands in the doorway, barely readable, with two pinprick
// eyes. Grain, fog and a heavy vignette keep it cinematic rather than cute.

uniform vec4 top_color : source_color = vec4(0.003, 0.006, 0.008, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.012, 0.018, 0.017, 1.0);
uniform vec4 haze_color : source_color = vec4(0.11, 0.22, 0.20, 1.0);
uniform vec4 door_color : source_color = vec4(0.30, 0.46, 0.39, 1.0);
uniform vec4 red_color : source_color = vec4(0.55, 0.025, 0.012, 1.0);
uniform float door_x : hint_range(0.1, 0.9) = 0.735;
uniform float door_strength : hint_range(0.0, 1.0) = 0.30;
uniform float figure_strength : hint_range(0.0, 1.0) = 0.92;
uniform float red_strength : hint_range(0.0, 1.0) = 0.55;
uniform float grain_amount : hint_range(0.0, 0.08) = 0.022;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.76;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	// The lit doorway: a tall, soft-edged rectangle at the right of frame.
	float dx = abs(uv.x - door_x);
	float doorway = (1.0 - smoothstep(0.055, 0.105, dx))
		* smoothstep(0.17, 0.29, uv.y)
		* (1.0 - smoothstep(0.84, 0.97, uv.y));
	col += door_color.rgb * doorway * door_strength;

	// Spill around the door and a weak sheen on the floor below it.
	vec2 dp = (uv - vec2(door_x, 0.55)) * vec2(1.45, 1.0);
	float spill = 1.0 - smoothstep(0.10, 0.48, length(dp));
	col += haze_color.rgb * spill * 0.075;
	float reflection = (1.0 - smoothstep(0.02, 0.15, dx))
		* smoothstep(0.69, 0.78, uv.y)
		* (1.0 - smoothstep(0.93, 1.0, uv.y));
	col += door_color.rgb * reflection * 0.055;

	// Slow, cold mist drifting through the room.
	float fog = fbm(uv * vec2(2.8, 1.7) + vec2(TIME * 0.010, TIME * 0.004));
	col += haze_color.rgb * smoothstep(0.48, 0.86, fog) * 0.052;

	// A figure in the doorway. The head and shoulders are subtracted into
	// near-black; only the shape edges catch the spill light.
	vec2 head_p = (uv - vec2(door_x, 0.495)) * vec2(1.0, 1.16);
	float head = 1.0 - smoothstep(0.038, 0.054, length(head_p));
	vec2 shoulder_p = (uv - vec2(door_x, 0.665)) * vec2(1.0, 2.05);
	float shoulders = 1.0 - smoothstep(0.112, 0.140, length(shoulder_p));
	float figure = max(head, shoulders);
	col = mix(col, vec3(0.0025, 0.004, 0.004), figure * figure_strength);

	// Two very faint sickly eyes; they should be discovered, not announced.
	float eye_l = 1.0 - smoothstep(0.0016, 0.0027, length(uv - vec2(door_x - 0.012, 0.482)));
	float eye_r = 1.0 - smoothstep(0.0016, 0.0027, length(uv - vec2(door_x + 0.012, 0.482)));
	col += vec3(0.55, 0.82, 0.46) * max(eye_l, eye_r) * 0.65;

	// A failing red emergency strip at the upper right, with a soft halo.
	float sign = (1.0 - smoothstep(0.003, 0.008, abs(uv.x - 0.882)))
		* smoothstep(0.195, 0.202, uv.y)
		* (1.0 - smoothstep(0.225, 0.233, uv.y));
	float red_pulse = 0.62 + 0.38 * sin(TIME * 1.35 + sin(TIME * 0.37) * 2.0);
	col += red_color.rgb * sign * red_strength * red_pulse;
	vec2 rp = (uv - vec2(0.882, 0.214)) * vec2(1.0, 2.8);
	col += red_color.rgb * (1.0 - smoothstep(0.015, 0.20, length(rp))) * 0.055 * red_pulse;

	// Damp wall grime and a slight lens-like unevenness from the fog.
	float grime = fbm(uv * vec2(5.3, 3.1) + vec2(TIME * 0.018, 0.0));
	col *= 0.84 + grime * 0.16;

	// Heavy cinematic vignette.
	vec2 v = uv - vec2(0.5, 0.48);
	float vig = smoothstep(0.30, 0.92, length(v) * 1.32);
	col *= 1.0 - vig * vignette_strength;

	// Fine grain.
	float grain = hash12(uv * vec2(1920.0, 1080.0) + vec2(TIME * 31.0, -TIME * 17.0)) - 0.5;
	col += grain * grain_amount;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
