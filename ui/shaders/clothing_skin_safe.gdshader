shader_type canvas_item;

// Recolorea la capa `clothing` del Avatar Mixer SIN pintar el cuello y las
// manos: esos píxeles de piel que el sprite de ropa trae en un tono carne
// fijo se llevan al color de PIEL elegido, no al de la camiseta. Antes,
// al teñir la ropa con el color del club, el cuello quedaba azul/rojo
// (bug reportado por Wilber: "partes del cuerpo de otro color").

uniform vec4 garment_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 skin_tint : source_color = vec4(1.0, 0.85, 0.72, 1.0);
uniform bool recolor_garment = true;   // false = deja la ropa cruda, solo arregla la piel
uniform float gain = 1.55;
uniform float ambient = 0.14;

// Heurística de "esto es piel" sobre el arte original del pack: tono
// cálido, r >= g >= b, con separación r-b moderada (ni gris ni saturado).
bool is_skin(vec3 c) {
	float rb = c.r - c.b;
	// tono carne Kenney: cálido, r claramente > g > b (g/r ~0.7..0.9),
	// separación r-b moderada. Excluye caquis/olivas (g pegado a r).
	return c.r > 0.42
		&& c.g < c.r * 0.92 && c.g > c.r * 0.55
		&& c.b < c.g * 0.95
		&& rb > 0.10 && rb < 0.62;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	if (is_skin(src.rgb)) {
		vec3 c = skin_tint.rgb * clamp(l * gain + ambient, 0.0, 1.25);
		COLOR = vec4(c, src.a);
	} else if (recolor_garment) {
		vec3 c = garment_tint.rgb * clamp(l * gain + ambient, 0.0, 1.25);
		COLOR = vec4(c, src.a * garment_tint.a);
	} else {
		COLOR = src;
	}
}
