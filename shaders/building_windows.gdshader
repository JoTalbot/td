// Окна небоскрёбов: часть окон случайно "горит" неоном.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.015, 0.015, 0.04, 1.0);
uniform vec4 window_color : source_color = vec4(0.2, 1.0, 1.0, 1.0);
uniform vec2 win_density = vec2(8.0, 14.0);
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.35;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * win_density);
	vec2 f = fract(UV * win_density);
	float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.75);
	float lit = step(1.0 - lit_ratio, hash(cell));
	// Лёгкое мерцание отдельных окон
	float flicker = 0.75 + 0.25 * sin(TIME * (1.5 + hash(cell + 7.0) * 4.0) + hash(cell) * 20.0);
	ALBEDO = base_color.rgb;
	METALLIC = 0.7;
	ROUGHNESS = 0.35;
	EMISSION = window_color.rgb * win * lit * 2.2 * flicker;
}
