shader_type canvas_item;
render_mode unshaded;

// Cinematic cold-grade for The Basement.
// The 3D layer is rendered first, then this pass:
//   * pulls the palette into sickly teal shadows and dirty amber highlights
//   * increases contrast and crushes the blacks
//   * adds a dirty-lens veil, fine grain and a restrained vignette
//   * exposes pulse / danger uniforms for the DreadDirector
// Keep PostFX.layer = 0 so the HUD is not graded.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D lens_dirt : hint_default_white, repeat_disable, filter_linear;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.52;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.32;
uniform float grain_amount : hint_range(0.0, 0.12) = 0.030;
uniform float grain_speed : hint_range(0.0, 120.0) = 24.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.26;
uniform float contrast : hint_range(0.5, 2.0) = 1.10;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.42;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.0011;
uniform float lens_dirt_amount : hint_range(0.0, 0.4) = 0.11;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.63, 0.65);
uniform vec3 mid_tint : source_color = vec3(0.72, 0.86, 0.74);
uniform vec3 highlight_tint : source_color = vec3(1.05, 0.91, 0.73);
uniform vec3 danger_tint : source_color = vec3(0.78, 0.07, 0.015);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float edge = dot(dir, dir);

	// Slight lens fringe toward the edges.
	vec3 col;
	col.r = texture(screen_texture, uv + dir * chromatic_aberration * edge).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - dir * chromatic_aberration * edge).b;

	// A dirty camera lens: smudges multiply the image and add a faint warm
	// dust veil. This keeps the frame from looking like clean CGI.
	vec4 dirt = texture(lens_dirt, uv);
	float dirt_mask = dirt.a * (0.45 + 0.55 * smoothstep(0.08, 0.75, dirt.r));
	col *= 1.0 - dirt_mask * lens_dirt_amount;
	col += vec3(0.022, 0.014, 0.007) * dirt_mask * lens_dirt_amount;

	// Desaturate, then apply a filmic contrast around mid-grey.
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	// Dark service corridors should read as damp and colourless; lit practicals
	// keep enough warm/cold separation to stay legible. This keeps the
	// basement from becoming a flat saturated green wash.
	float shadow_desat = (1.0 - smoothstep(0.01, 0.12, luma)) * 0.18;
	col = mix(col, vec3(luma), clamp(desaturation + shadow_desat, 0.0, 1.0));
	// Use a low pivot: crushing around mid-grey turns a dark room into a
	// featureless black screen. This keeps the shadows readable while still
	// giving the image a hard, filmic shoulder.
	col = (col - 0.15) * contrast + 0.15;
	col = max(col, vec3(0.0));

	// Split-tone: cold, almost green shadows; dirty amber practicals.
	vec3 tint = mix(shadow_tint, mid_tint, smoothstep(0.04, 0.54, luma));
	tint = mix(tint, highlight_tint, smoothstep(0.55, 0.94, luma));
	col *= mix(vec3(1.0), tint, tint_amount);

	// A whisper of red in the deep shadows when something is wrong.
	col += danger_tint * danger * (1.0 - smoothstep(0.0, 0.50, luma)) * 0.085;

	// Cinematic vignette with a slow breathing component from the director.
	float d = distance(uv, vec2(0.5)) * 1.41421356;
	float vig = smoothstep(vignette_start, 1.0, d);
	float strength = vignette_strength + pulse * 0.075 + danger * 0.035;
	col *= 1.0 - vig * strength;

	// Two-scale monochrome grain: fine sensor noise plus coarse film texture.
	float n1 = hash12(uv * vec2(1920.0, 1080.0) + vec2(TIME * grain_speed, TIME * grain_speed * 0.71));
	float n2 = hash12(uv * vec2(287.0, 161.0) + vec2(-TIME * 6.3, TIME * 8.7));
	col += ((n1 - 0.5) * 0.78 + (n2 - 0.5) * 0.22) * grain_amount;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
