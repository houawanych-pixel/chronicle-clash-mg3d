shader_type spatial;
// CC unified foliage shader: leaves, vines, flowers (and the big snapping flower) all use it.
//  - Wind sway: vertex displacement weighted by UV2.x (0 = root / anchor, pinned; 1 = tip),
//    phase from WORLD position so neighbouring cards and merged clusters sway together
//    without tearing at shared edges.
//  - Biome palette: UV2.y holds the palette slot (biome * 16 + role). The colours come from the
//    `palette` uniform (FoliagePalette), so one block type serves every planet / biome.
//  - Double-sided alpha-scissor cards (crisp leaf edges, depth written: no sorting).
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 palette[64];
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.0);
uniform float wind_strength = 1.0;
uniform float sway_amount = 0.09;
uniform float scissor = 0.5;

varying float slot;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = clamp(UV2.x, 0.0, 1.0);
	float ph = dot(wp.xz, vec2(0.37, 0.29));
	float gust = sin(TIME * 1.6 + ph) * 0.65 + sin(TIME * 2.7 + ph * 1.9) * 0.35;
	vec3 d = normalize(wind_dir + vec3(0.0001));
	vec3 off = (d * gust + vec3(0.0, -0.15 * abs(gust), 0.0)) * sway_amount * wind_strength * w * w;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	slot = UV2.y;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	int i = clamp(int(slot + 0.5), 0, 63);
	vec3 tint = palette[i].rgb;
	ALBEDO = t.rgb * tint * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	ROUGHNESS = 0.85;
	BACKLIGHT = ALBEDO * 0.35;
}
