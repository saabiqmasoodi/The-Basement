shader_type spatial;
render_mode cull_disabled;

// Portrait-only material for the menu Friend duplicate. The head is removed
// twice: head-weighted triangles are deleted in GDScript, and this world-space
// clip guarantees no head/collar geometry can remain above the neck. The game
// Friend never uses this material.

uniform vec4 albedo : source_color = vec4(0.78, 0.78, 0.78, 1.0);
uniform vec4 emission_color : source_color = vec4(0.02, 0.017, 0.014, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.82;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.28;
uniform float cutoff_y = 1.49;

varying vec3 world_pos;
varying vec4 vertex_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_color = COLOR;
}

void fragment() {
	if (world_pos.y > cutoff_y) {
		discard;
	}

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 base = albedo.rgb * vertex_color.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
	EMISSION = emission_color.rgb + base * fresnel * rim_strength;
}
