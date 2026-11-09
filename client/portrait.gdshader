shader_type canvas_item;
// Recorta el retrato en un círculo y lo pasa a gris mientras el héroe está muerto.

uniform bool dead = false;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float edge = smoothstep(0.5, 0.49, distance(UV, vec2(0.5)));
	if (dead) {
		color.rgb = vec3(dot(color.rgb, vec3(0.3, 0.59, 0.11)) * 0.6);
	}
	COLOR = vec4(color.rgb, color.a * edge);
}
