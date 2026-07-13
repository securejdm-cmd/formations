shader_type canvas_item;

// Procedural crumbling-crack band — deterministic per unit (render_seed), static, no shimmer.
uniform vec4 team_color : source_color = vec4(0.5, 0.15, 0.15, 1.0);
uniform float render_seed = 0.0;
uniform float edge_wobble_amp = 0.06;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float voronoi_cracks(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 1.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash21(n + g), hash21(n + g + vec2(17.3, 9.1)));
			vec2 r = g + o - f;
			md = min(md, dot(r, r));
		}
	}
	return sqrt(md);
}

void fragment() {
	vec2 uv = UV;
	float seed = render_seed * 0.001;

	// Irregular rear boundary (uv.x = 0): noise-modulated cutoff per scanline.
	float wobble = (value_noise(vec2(uv.y * 14.0, seed + 3.7)) - 0.5) * edge_wobble_amp;
	if (uv.x < wobble) {
		discard;
	}

	vec2 crack_uv = vec2(uv.x * 3.5 + seed, uv.y * 5.0 + seed * 1.7);
	float vor = voronoi_cracks(crack_uv);
	float grain = value_noise(crack_uv * 2.3 + seed);
	float fracture = smoothstep(0.04, 0.22, vor) * 0.75 + smoothstep(0.35, 0.65, grain) * 0.35;
	fracture = clamp(fracture, 0.0, 1.0);

	vec3 earth_base = team_color.rgb * 0.52;
	vec3 fracture_col = vec3(0.06, 0.05, 0.04);
	vec3 col = mix(earth_base, fracture_col, fracture);
	COLOR = vec4(col, team_color.a);
}
