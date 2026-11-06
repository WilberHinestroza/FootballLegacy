// Red de portería: malla de cuadros (rombos) dibujada en una cara plana; lo demás es transparente.
// `size` = medidas de la cara en metros, para que los cuadros salgan iguales en todas las caras.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 size = vec2(2.0, 2.0);
uniform float cell = 0.17;
uniform float thickness = 2.2; // grosor de la cuerda en píxeles
uniform vec3 color : source_color = vec3(0.96, 0.96, 0.96);
// Golpe del balón al marcar: la red se hincha hacia fuera alrededor de `hit` (en UV) y vibra
uniform vec2 hit = vec2(0.5, 0.3);
uniform float pulse = 0.0;
uniform vec3 push_dir = vec3(1.0, 0.0, 0.0);

void vertex() {
	vec2 d = (UV - hit) * size;
	float bump = exp(-dot(d, d) * 1.2);
	VERTEX += push_dir * pulse * 0.45 * bump * (0.75 + 0.25 * sin(TIME * 22.0));
}

void fragment() {
	vec2 p = UV * size / cell;
	p = vec2(p.x + p.y, p.x - p.y) * 0.7071; // en diagonal, como las redes reales
	vec2 g = abs(fract(p) - 0.5);
	vec2 fw = fwidth(p);
	vec2 l = 1.0 - smoothstep(vec2(0.0), fw * thickness, 0.5 - g);
	float line = max(l.x, l.y);
	// A lo lejos las cuerdas se funden: velo suave en vez de parpadeo
	float far = clamp(max(fw.x, fw.y) * 2.0 - 0.3, 0.0, 1.0);
	float a = mix(line, 0.22, far);
	if (a < 0.03) {
		discard;
	}
	ALBEDO = color;
	ALPHA = a;
	ROUGHNESS = 0.9;
}
