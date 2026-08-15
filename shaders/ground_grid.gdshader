// Бесконечная неоновая сетка с пульсацией, расходящейся от центра.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.008, 0.006, 0.025, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 0.12, 0.75, 1.0);
uniform float cell_size = 2.0;
uniform float line_width = 0.07;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = abs(fract(wpos.xz / cell_size - 0.5) - 0.5) * cell_size;
	float line = 1.0 - smoothstep(0.0, line_width, min(g.x, g.y));
	float pulse = 1.0 + 0.7 * sin(TIME * 2.0 - length(wpos.xz) * 0.18);
	float fade = 1.0 - smoothstep(10.0, 45.0, length(wpos.xz));
	ALBEDO = base_color.rgb;
	METALLIC = 0.8;
	ROUGHNESS = 0.3;
	EMISSION = line_color.rgb * line * pulse * fade * 1.4;
}
