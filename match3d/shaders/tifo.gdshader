// Tifo: lona sobre la grada de fondo, hecha de "cartulinas" (cada aficionado sostiene una).
// El emblema (máscara en blanco y negro) va en el centro sobre franjas, con los dos colores del club.
// `reveal` lo despliega de abajo arriba (0 = recogido, 1 = desplegado).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D mask : filter_linear, hint_default_white;
uniform vec3 c1 : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 c2 : source_color = vec3(1.0);
uniform float reveal = 1.0;
uniform float aspect = 6.0;        // ancho / alto de la lona
uniform vec2 cells = vec2(160.0, 26.0);
uniform float stripes = 14.0;

void vertex() {
	// Ondea un poco, como una tela sostenida por la grada
	VERTEX.z += sin(VERTEX.x * 0.7 + TIME * 1.8) * 0.06 + sin(VERTEX.y * 1.4 + TIME * 1.2) * 0.04;
}

void fragment() {
	vec2 uv = UV;
	if (1.0 - uv.y > reveal) { discard; }
	vec2 cell = floor(uv * cells);
	vec2 cuv = (cell + 0.5) / cells;
	// Emblema cuadrado en el centro, el resto franjas verticales
	vec2 e = vec2((cuv.x - 0.5) * aspect / 1.02 + 0.5, (cuv.y - 0.5) / 1.02 + 0.5);
	float on_emblem = step(0.0, e.x) * step(e.x, 1.0) * step(0.0, e.y) * step(e.y, 1.0);
	float m = texture(mask, clamp(e, 0.0, 1.0)).r;
	float stripe = step(0.5, fract(cuv.x * stripes));
	float use2 = on_emblem > 0.5 ? step(0.5, m) : stripe;
	// Marco del emblema en el segundo color
	vec2 d = abs(e - 0.5);
	float ring = on_emblem * step(0.47, max(d.x, d.y));
	use2 = max(use2 * (1.0 - ring), 0.0);
	vec3 col = mix(c1, c2, use2);
	col = mix(col, c1 * 0.55, ring);
	// Cada cartulina algo distinta y con una rendija oscura entre ellas
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.86 + h * 0.22;
	vec2 f = fract(uv * cells);
	float gap = step(0.07, f.x) * step(0.07, f.y) * step(f.x, 0.95) * step(f.y, 0.95);
	col *= mix(0.4, 1.0, gap);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}
