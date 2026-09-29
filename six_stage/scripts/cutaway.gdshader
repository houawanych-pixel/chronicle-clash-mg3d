// Stage surface with Metal Gear-style cutaway: anything above the player's floor that sits
// between the camera and the player is cut out, with a thin lit edge where it was cut.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform vec4 albedo : source_color = vec4(0.5, 0.56, 0.58, 1.0);
uniform float emission_strength = 0.0;
uniform vec3 focus_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 camera_pos = vec3(0.0, 1000.0, 0.0);
uniform float feet_y = -1000.0;
uniform float cut_radius = 2.4;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 col = albedo.rgb;
	vec3 seg = focus_pos - camera_pos;
	float len = length(seg);
	if (len > 0.01) {
		vec3 dir = seg / len;
		float t = dot(world - camera_pos, dir);
		if (t > 0.0 && t < len - 0.5 && world.y > feet_y + 0.4) {
			float d = length(world - (camera_pos + dir * t));
			float r = cut_radius * clamp(t / len, 0.35, 1.0) + 0.35;
			if (d < r) { discard; }
			if (d < r + 0.09) { col = vec3(0.45, 1.0, 0.85); }
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	EMISSION = col * emission_strength;
}
