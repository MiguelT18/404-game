// Tajo que recorre un arco. UV.x va de un extremo del arco al otro y
// UV.y del borde de abajo al filo. `progress` avanza de 0 a 1 + `tail`.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.0;
uniform float progress = 0.0;
uniform float tail = 0.5;

void fragment() {
	float behind = progress - UV.x;
	float trail = step(0.0, behind) * sqrt(clamp(1.0 - behind / tail, 0.0, 1.0));
	// Más brillante cerca del filo, como una estela de metal.
	float body = smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(0.9, 1.0, UV.y));
	float edge = smoothstep(0.7, 0.88, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	ALBEDO = mix(color.rgb, vec3(1.0), edge * 0.8) * energy;
	ALPHA = clamp(trail * (body * 0.85 + edge), 0.0, 1.0);
}
