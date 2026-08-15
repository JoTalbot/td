// Голографическая вывеска: скан-линии, мерцание, мягкие края.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.2, 1.0, 1.0, 1.0);
uniform float speed = 1.0;

void fragment() {
	float scan = 0.6 + 0.4 * sin(UV.y * 60.0 - TIME * 5.0 * speed);
	float flicker = 0.82 + 0.18 * sin(TIME * 13.0 * speed + UV.x * 5.0);
	float glitch = step(0.97, fract(sin(floor(TIME * 6.0) * 91.7) * 43758.5)) * 0.5;
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x)
		* smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.92, UV.y);
	ALBEDO = color.rgb * scan * flicker * edge * (1.0 - glitch);
	ALPHA = 0.55 * edge;
}
