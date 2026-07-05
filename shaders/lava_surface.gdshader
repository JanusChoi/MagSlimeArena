shader_type canvas_item;

uniform float heat_time = 0.0;
uniform float intensity = 1.0;

float wave(float x, float t, float freq, float amp) {
	return sin(x * freq + t) * amp;
}

void fragment() {
	vec2 uv = UV;
	float t = heat_time;

	// uv.y = 0 为液面（控件顶边，与死亡判定线对齐）
	float surface = 0.04
		+ wave(uv.x, t * 2.2, 8.0, 0.022 * intensity)
		+ wave(uv.x, t * 3.7 + 1.3, 14.0, 0.014 * intensity)
		+ wave(uv.x, t * 1.1 + 2.7, 22.0, 0.007 * intensity);

	float crest = smoothstep(surface + 0.03, surface - 0.02, uv.y);
	float body = smoothstep(0.0, 0.65, uv.y);

	vec3 deep_col = vec3(0.38, 0.04, 0.01);
	vec3 mid_col = vec3(0.78, 0.18, 0.03);
	vec3 hot_col = vec3(1.0, 0.48, 0.08);
	vec3 crest_col = vec3(1.0, 0.88, 0.42);

	vec3 col = mix(deep_col, mid_col, body);
	col = mix(col, hot_col, crest * 0.85);
	col = mix(col, crest_col, crest * crest * (0.65 + 0.35 * sin(t * 5.0 + uv.x * 18.0)));

	float flicker = 0.9 + 0.1 * sin(t * 7.0 + uv.x * 24.0);
	col *= flicker;

	COLOR = vec4(col, 0.92);
}
