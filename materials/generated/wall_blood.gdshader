shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

// Blood marks on the menu wall. The source decal texture is a dark red mask,
// so use its alpha only and drive the colour from a single uniform. That keeps
// the wall splatter clearly red after the menu's heavy final grade.

uniform sampler2D blood_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 blood_color : source_color = vec4(0.72, 0.012, 0.007, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(blood_texture, UV);
	// Fade the last few percent of the quad so a straight texture border can
	// never read as a square panel on the wall.
	float edge = smoothstep(0.0, 0.035, UV.x)
		* smoothstep(0.0, 0.035, 1.0 - UV.x)
		* smoothstep(0.0, 0.035, UV.y)
		* smoothstep(0.0, 0.035, 1.0 - UV.y);
	float density = tex.a;
	ALBEDO = blood_color.rgb * (0.42 + 0.38 * density);
	ROUGHNESS = 0.15;
	SPECULAR = 0.78;
	EMISSION = blood_color.rgb * (0.10 + 0.10 * density);
	ALPHA = density * opacity * blood_color.a * edge;
}
