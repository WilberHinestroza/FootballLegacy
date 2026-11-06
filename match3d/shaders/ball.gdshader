shader_type spatial;
// Balón de paneles: celdas de Voronoi sobre la esfera con 12 centros de pentágono
// (vértices del icosaedro) y 20 de hexágono (sus caras) = icosaedro truncado.
// Los paneles están en espacio local, así que giran con el balón.
//   style 0: clásico (pentágonos de color panel)
//   style 1: moderno (hexágonos con franja de color en tríada)
//   style 2: liga (pentágonos de color con borde oscuro)
//   style 3: estrella (estrella blanca dentro de cada pentágono)
//   style 4: remolino (franjas en espiral alrededor del eje)
//   style 5: cuero retro (gajos alargados con cordones)
//   style 6: bandera tricolor (panel | base | accent)
//   style 7: circuito (costuras de neón)
//   style 8: luna (dos mitades con borde en S)
//   style 9: llamas
//   style 10: camuflaje

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.95);
uniform vec3 panel_color : source_color = vec3(0.07, 0.07, 0.09);
uniform vec3 accent_color : source_color = vec3(0.9, 0.15, 0.2);
uniform int style = 0;
uniform float pent_shrink = 0.0;
uniform float metal = 0.0;
// Variación de tono por panel (balones metálicos o de cuero: cada panel brilla distinto)
uniform float panel_shade = 0.0;

varying vec3 lp;

const float PHI = 1.618034;
const float IPHI = 0.618034;

void vertex() {
	lp = normalize(VERTEX);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void fragment() {
	vec3 n = normalize(lp);
	// Pentágonos (icosaedro). Se agrandan un poco para que los paneles queden regulares.
	vec3 pv[12] = vec3[](
		vec3(0.0, 1.0, PHI), vec3(0.0, -1.0, PHI), vec3(0.0, 1.0, -PHI), vec3(0.0, -1.0, -PHI),
		vec3(1.0, PHI, 0.0), vec3(-1.0, PHI, 0.0), vec3(1.0, -PHI, 0.0), vec3(-1.0, -PHI, 0.0),
		vec3(PHI, 0.0, 1.0), vec3(-PHI, 0.0, 1.0), vec3(PHI, 0.0, -1.0), vec3(-PHI, 0.0, -1.0));
	vec3 hv[20] = vec3[](
		vec3(1.0, 1.0, 1.0), vec3(1.0, 1.0, -1.0), vec3(1.0, -1.0, 1.0), vec3(1.0, -1.0, -1.0),
		vec3(-1.0, 1.0, 1.0), vec3(-1.0, 1.0, -1.0), vec3(-1.0, -1.0, 1.0), vec3(-1.0, -1.0, -1.0),
		vec3(0.0, PHI, IPHI), vec3(0.0, PHI, -IPHI), vec3(0.0, -PHI, IPHI), vec3(0.0, -PHI, -IPHI),
		vec3(IPHI, 0.0, PHI), vec3(-IPHI, 0.0, PHI), vec3(IPHI, 0.0, -PHI), vec3(-IPHI, 0.0, -PHI),
		vec3(PHI, IPHI, 0.0), vec3(PHI, -IPHI, 0.0), vec3(-PHI, IPHI, 0.0), vec3(-PHI, -IPHI, 0.0));
	float best = -2.0;
	float second = -2.0;
	bool pent = false;
	vec3 center = vec3(0.0, 1.0, 0.0);
	for (int i = 0; i < 12; i++) {
		float d = dot(n, normalize(pv[i])) - pent_shrink;
		if (d > best) { second = best; best = d; pent = true; center = normalize(pv[i]); }
		else if (d > second) { second = d; }
	}
	for (int i = 0; i < 20; i++) {
		float d = dot(n, normalize(hv[i]));
		if (d > best) { second = best; best = d; pent = false; center = normalize(hv[i]); }
		else if (d > second) { second = d; }
	}
	// Costuras: donde los dos centros más cercanos están casi a la misma distancia
	float edge = best - second;
	float w = fwidth(edge) * 1.2;
	float seam = 1.0 - smoothstep(0.004, 0.004 + w, edge);
	// Coordenadas dentro del panel: ángulo y radio alrededor de su centro
	vec3 t = normalize(cross(center, abs(center.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 bt = cross(center, t);
	vec3 q = n - center * dot(n, center);
	float ang = atan(dot(q, bt), dot(q, t));
	float r = length(q);

	vec3 col = base_color;
	vec3 emit = vec3(0.0);
	float seam_dark = 0.35;
	if (style == 0) {
		if (pent) col = panel_color;
	} else if (style == 1) {
		if (pent) {
			col = panel_color;
		} else {
			// Franja curva dentro de cada hexágono, girando alrededor del centro
			float band = sin(ang + r * 9.0);
			col = mix(col, accent_color, smoothstep(0.88, 0.93, band) * smoothstep(0.05, 0.12, r));
		}
	} else if (style == 2) {
		if (pent) {
			float ring = smoothstep(0.03, 0.026, edge);
			col = mix(accent_color, panel_color, ring);
		}
	} else if (style == 3) {
		// Estrella de 5 puntas en los pentágonos; los hexágonos, más claros alrededor
		if (pent) {
			float k = cos(5.0 * ang) * 0.5 + 0.5;
			float star_r = mix(0.11, 0.3, k * k);
			col = mix(accent_color, panel_color, smoothstep(star_r + 0.012, star_r, r));
		} else {
			col = mix(base_color, base_color * 1.25 + 0.05, smoothstep(0.25, 0.1, r));
		}
	} else if (style == 4) {
		// Remolino: franjas que giran con la altura alrededor del eje Y
		float a2 = atan(n.x, n.z) + n.y * 5.0;
		float s = sin(a2 * 2.0);
		col = mix(base_color, panel_color, smoothstep(0.25, 0.32, s));
		col = mix(col, accent_color, smoothstep(0.3, 0.35, s) * (1.0 - smoothstep(0.48, 0.53, s)));
		col = mix(col, accent_color, smoothstep(-0.55, -0.5, s) * (1.0 - smoothstep(-0.42, -0.37, s)));
		seam_dark = 0.8;
	} else if (style == 5) {
		// Cuero: 6 gajos (caras de un cubo) partidos en 3 tiras, con cordones arriba
		vec3 an = abs(n);
		float u;
		float major;
		if (an.x > an.y && an.x > an.z) { u = n.y / an.x; major = 0.0; }
		else if (an.y > an.z) { u = n.z / an.y; major = 1.0; }
		else { u = n.x / an.z; major = 2.0; }
		float strip = abs(fract(u * 1.5 + 0.5) - 0.5);
		float m1 = min(min(abs(an.x - an.y), abs(an.y - an.z)), abs(an.x - an.z));
		float sw = fwidth(m1) * 1.5;
		seam = max(1.0 - smoothstep(0.0, 0.012 + sw, m1), 1.0 - smoothstep(0.0, 0.03, strip));
		float tone = hash3(vec3(floor(u * 1.5 + 0.5), major, sign(dot(n, vec3(1.0)))));
		col = base_color * (0.85 + tone * 0.3);
		// Cordones: cruces cortas en lo alto
		float lace = (an.y > an.x && an.y > an.z && n.y > 0.0 && abs(n.z / an.y) < 0.4) ? 1.0 : 0.0;
		float lx = abs(n.x / an.y);
		float bar = step(abs(fract(n.z / an.y * 5.0) - 0.5), 0.12) * step(lx, 0.12);
		float slit = step(lx, 0.015);
		col = mix(col, accent_color, lace * max(bar, slit));
		seam_dark = 0.45;
	} else if (style == 6) {
		// Bandera: tres franjas verticales
		col = n.x < -0.33 ? panel_color : (n.x > 0.33 ? accent_color : base_color);
		if (pent && abs(n.x) < 0.33) col = mix(col, vec3(0.85), 0.3);
	} else if (style == 7) {
		// Circuito: paneles oscuros, pentágonos morados y costuras de neón
		if (pent) col = mix(base_color, panel_color, smoothstep(0.2, 0.16, r) * 0.6 + 0.2);
		float glow = 1.0 - smoothstep(0.0, 0.03, edge);
		float inner = smoothstep(0.012, 0.0, abs(r - 0.2)) * (pent ? 1.0 : 0.0);
		col = mix(col, accent_color, max(glow, inner));
		emit = accent_color * max(glow, inner) * 1.4;
		seam = 0.0;
	} else if (style == 8) {
		// Luna: dos mitades separadas por una curva en S
		float s = n.x + 0.45 * sin(n.y * 3.0);
		col = mix(panel_color, base_color, smoothstep(-0.02, 0.02, s));
		seam_dark = 0.75;
	} else if (style == 9) {
		// Llamas que suben desde abajo
		float a2 = atan(n.x, n.z);
		float fl = n.y + 0.22 * sin(a2 * 7.0 + n.y * 4.0) + 0.12 * noise3(n * 6.0);
		col = mix(accent_color, panel_color, smoothstep(-0.35, -0.2, fl));
		col = mix(col, base_color, smoothstep(0.1, 0.3, fl));
		emit = accent_color * 0.25 * (1.0 - smoothstep(-0.35, -0.1, fl));
		seam_dark = 0.7;
	} else if (style == 10) {
		// Camuflaje: manchas de ruido en tres tonos
		float c1 = noise3(n * 3.5);
		float c2 = noise3(n * 3.5 + vec3(7.1, 2.3, 5.7));
		col = mix(base_color, panel_color, step(0.55, c1));
		col = mix(col, accent_color, step(0.62, c2));
	}
	if (panel_shade > 0.0) {
		col *= 1.0 - panel_shade + panel_shade * 2.0 * hash3(center * 7.0) * smoothstep(0.32, 0.0, r);
	}
	col = mix(col, col * seam_dark, seam);
	ALBEDO = col;
	EMISSION = emit;
	METALLIC = metal;
	ROUGHNESS = mix(mix(0.38, 0.22, metal), 0.75, seam);
	SPECULAR = 0.45;
}
