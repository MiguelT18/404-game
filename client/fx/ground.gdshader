// Marca circular en el suelo, sobre un PlaneMesh de lado 2 × radio.
// Con `ring_width` 0 es un disco suave; si no, un anillo en `ring_radius`.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform float alpha = 1.0;
uniform float ring_radius = 1.0;
uniform float ring_width = 0.0;
// Velocidad del remolino de escarcha; 0 lo apaga.
uniform float swirl = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a;
	if (ring_width > 0.0) {
		a = 1.0 - smoothstep(0.0, ring_width, abs(d - ring_radius));
	} else {
		a = 1.0 - smoothstep(ring_radius * 0.5, ring_radius, d);
	}
	if (swirl > 0.0) {
		float angle = atan(p.y, p.x);
		float pattern = 0.5 + 0.5 * sin(angle * 9.0 + d * 14.0 - TIME * swirl);
		float cracks = smoothstep(0.92, 1.0, sin(angle * 23.0 + sin(d * 9.0) * 2.0));
		float rim = smoothstep(0.8, 0.97, d) * (1.0 - smoothstep(0.97, 1.0, d));
		a = a * (0.3 + 0.25 * pattern + 0.3 * cracks) + rim;
	}
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(a * alpha * color.a, 0.0, 1.0) * step(d, 1.0);
}
