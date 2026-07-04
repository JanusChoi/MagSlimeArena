shader_type canvas_item;

uniform float heat_time = 0.0;
uniform float intensity = 1.0;

float wave(float x, float t, float freq, float amp) {
	return sin(x * freq + t) * amp;
}

void fragment() {
	vec2 uv = UV;
	float t = heat_time;

	float surface = 0.08
		+ wave(uv.x, t * 2.2, 8.0, 0.025 * intensity)
		+ wave(uv.x, t * 3.7 + 1.3, 14.0, 0.015 * intensity)
		+ wave(uv.x, t * 1.1 + 2.7, 22.0, 0.008 * intensity);

	float edge = smoothstep(surface + 0.02, surface - 0.04, uv.y);
	float deep = smoothstep(0.0, 0.55, uv.y);

	vec3 deep_col = vec3(0.45, 0.05, 0.02);
	vec3 mid_col = vec3(0.85, 0.22, 0.04);
	vec3 hot_col = vec3(1.0, 0.55, 0.12);
	vec3 crest_col = vec3(1.0, 0.85, 0.35);

	vec3 col = mix(deep_col, mid_col, deep);
	col = mix(col, hot_col, edge);
	col = mix(col, crest_col, edge * edge * (0.6 + 0.4 * sin(t * 5.0 + uv.x * 20.0)));

	float flicker = 0.92 + 0.08 * sin(t * 8.0 + uv.x * 30.0);
	col *= flicker;

	COLOR = vec4(col, 0.88 + edge * 0.1);
}
