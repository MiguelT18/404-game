// Burbuja de escudo: casi invisible de frente y brillante en el contorno.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.5;
uniform float alpha = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// Franjas que suben despacio para que se note que está activo.
	float bands = 0.5 + 0.5 * sin((UV.y * 40.0) - TIME * 3.0);
	ALBEDO = color.rgb * energy;
	ALPHA = clamp((rim * 0.9 + bands * 0.06 + 0.04) * alpha, 0.0, 1.0);
}
