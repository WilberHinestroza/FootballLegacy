// Pintado del jugador por píxel (lo incluyen player_zones y player_zones_fade).
// tools/build_player_glb.py guarda por vértice la posición de la pose original (en A),
// en fracciones de la altura total, así los bordes de las zonas son líneas lisas:
//   UV  = (x desde el centro + 0.5, altura f: 0 pies · 1 coronilla)
//   UV2 = (profundidad desde la punta de la nariz + 0.5, posición en el brazo: 0 hombro · 1 codo)
//   COLOR = (peso de brazo, peso de cabeza y cuello)

uniform vec3 skin_color : source_color = vec3(0.87, 0.67, 0.5);
uniform vec3 shirt_color : source_color = vec3(0.86, 0.13, 0.16);
uniform vec3 shorts_color : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 socks_color : source_color = vec3(0.86, 0.13, 0.16);
uniform vec3 boots_color : source_color = vec3(0.08, 0.08, 0.08);
uniform vec3 hair_color : source_color = vec3(0.35, 0.22, 0.12);
// Pelo: 0 rapado · 1 calvo · 2 degradado · 3 cresta (show_hair = false lo oculta igual que calvo)
uniform bool show_hair = true;
uniform int hair_style = 0;
// Barba: 0 ninguna · 1 barba · 2 de 3 días · 3 candado · 4 bigote · 5 barba larga
uniform int beard_style = 0;
// Diseño de la camiseta (shirt_color + shirt_color2):
// 0 lisa · 1 rayas verticales · 2 aros · 3 mitades · 4 banda diagonal · 5 V en el pecho
// 6 rayas finas · 7 hombros y mangas · 8 peto de suplente · 9 traje (DT: chaqueta, camisa y corbata)
// 10 cuadros (Croacia) · 11 franja en el pecho (Boca) · 12 franja central con filos (PSG)
// 13 costados del segundo color · 14 V ancha en el pecho (México)
uniform int shirt_pattern = 0;
uniform vec3 shirt_color2 : source_color = vec3(1.0);
// Ropa de calle / banquillo: manga larga y pantalón largo (DT, suplentes, cámaras)
uniform bool long_sleeves = false;
uniform bool long_pants = false;
// Zapatos de calle: suela de otro color (los guayos no la llevan)
uniform bool use_sole = false;
uniform vec3 sole_color : source_color = vec3(0.1);
// Guantes de portero: palma y dorso de glove_color, puño de glove_color2
uniform bool gloves = false;
uniform vec3 glove_color : source_color = vec3(0.95);
uniform vec3 glove_color2 : source_color = vec3(0.1);
// Estampados (KitDecals): atlas 256² con escudo (arriba izq.), dorsal (arriba der.),
// patrocinio (franja de en medio) y apellido (abajo). use_decals = false = camiseta lisa.
uniform sampler2D kit_decals : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_decals = false;
uniform bool crest_center = false; // escudo en el centro del pecho (también siempre en el polo retro, 23)
uniform float decal_flip = 1.0; // -1 con el modelo espejado (zurdos): el texto se sigue leyendo bien
// Parpadeo: cada jugador con su ritmo (semilla 0-1); a veces parpadea dos veces seguidas
uniform float blink_seed = 0.0;
uniform float blink_force = -1.0; // >= 0: ojos fijos (0 abiertos, 1 cerrados), p. ej. tras una entrada

float blink_amount() {
	if (blink_force >= 0.0) { return blink_force; }
	float per = 2.8 + blink_seed * 2.6;
	float t = mod(TIME + blink_seed * 17.0, per);
	float one = 1.0 - smoothstep(0.0, 0.075, abs(t - 0.08));
	float two = (blink_seed > 0.6 ? 1.0 : 0.0) * (1.0 - smoothstep(0.0, 0.07, abs(t - 0.32)));
	return max(one, two);
}

// Medidas de la malla (fracción de la altura). La nariz es el punto más adelantado de la cabeza.
const float NOSE_F = 0.8335;
const float HEAD_HALF = 0.1025;
const float HEAD_DEPTH = 0.2484;
const float SHIRT_BOTTOM = 0.41;
const float SHORTS_BOTTOM = 0.245;
const float SOCKS_TOP = 0.098;
const float BOOTS_TOP = 0.068;
const float COLLAR_F = 0.752;
const float SLEEVE_END = 0.55;
const float WRIST_T = 2.1;    // manga larga: hasta la muñeca (la mano, piel)

varying vec2 body_a;
varying vec2 body_b;
varying vec2 body_w;

void vertex() {
	body_a = UV;
	body_b = UV2;
	body_w = COLOR.rg;
	// Ropa con volumen: la malla es una sola piel, así que el pantalón se separa un poco
	// de la pierna (si no, parece pintado, como unas mallas). La pantaloneta se abre hacia
	// el bajo (más ancha abajo, como la de verdad); el pantalón largo cae recto hasta el
	// zapato. Los guantes abultan la mano. (Con el esqueleto ya aplicado: sigue la animación.)
	float f = UV.y;
	float inflate = 0.0;
	if (COLOR.r < 0.5 && COLOR.g < 0.5) {
		if (long_pants) {
			if (f > BOOTS_TOP + 0.004 && f < SHIRT_BOTTOM) {
				inflate = mix(0.026, 0.008, smoothstep(0.33, 0.40, f));
			}
		} else if (f > SHORTS_BOTTOM - 0.004 && f < SHIRT_BOTTOM) {
			inflate = mix(0.032, 0.007, smoothstep(0.26, 0.40, f));
		}
	} else if (gloves && COLOR.r > 0.5 && UV2.y * 3.0 - 0.5 > WRIST_T - 0.12) {
		inflate = 0.016;
	}
	VERTEX += NORMAL * inflate;
}

// 1 dentro de la elipse (centro c, radios r), con borde suavizado
float ellipse(vec2 p, vec2 c, vec2 r) {
	float d = length((p - c) / r) - 1.0;
	float aa = fwidth(d) * 1.2 + 0.001;
	return 1.0 - smoothstep(-aa, aa, d);
}

// 1 cuando v < edge, con borde suavizado
float below(float v, float edge) {
	float aa = fwidth(v) * 0.8 + 0.0003;
	return 1.0 - smoothstep(edge - aa, edge + aa, v);
}

float luma(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

// Ribete de la equipación: oscuro sobre colores claros, claro sobre oscuros
vec3 trim_of(vec3 c) {
	return luma(c) > 0.55 ? c * 0.45 : mix(c, vec3(1.0), 0.72);
}

vec3 head_color(float x, float ax, float f, float dn) {
	float fn = f - NOSE_F;
	vec3 c = skin_color;
	vec3 beard_c = hair_color * 0.8;
	// --- Barba: el borde de atrás sube en diagonal hacia la patilla ---
	float sideburn = smoothstep(0.06, 0.095, ax);
	float front = below(dn - (fn + 0.02) * 2.5, 0.5);
	// Borde inferior: baja por debajo de la mandíbula y se difumina hacia el cuello (no corte recto)
	float low = beard_style == 5 ? COLLAR_F + 0.01 : NOSE_F - 0.085 - 0.012 * (1.0 - sideburn);
	float full = below(fn, -0.008 + 0.034 * sideburn) * front * smoothstep(low - 0.012, low + 0.014, f);
	vec2 pm = vec2(ax, fn);
	float near = below(dn, 0.4);
	float moustache = ellipse(pm, vec2(0.0, -0.0145), vec2(0.03, 0.0062)) * near;
	// Candado: perilla maciza en la barbilla unida al bigote por las comisuras
	// (separada del labio por piel, para que no parezca una boca abierta)
	float goatee = max(max(ellipse(pm, vec2(0.0, -0.052), vec2(0.016, 0.0125)),
		ellipse(pm, vec2(0.006, -0.042), vec2(0.007, 0.004))),
		ellipse(pm, vec2(0.026, -0.024), vec2(0.0042, 0.011))) * near;
	float beard = 0.0;
	if (beard_style == 1 || beard_style == 5) { beard = max(full, moustache); }
	else if (beard_style == 2) { beard = max(full, moustache) * 0.45; }
	else if (beard_style == 3) { beard = max(moustache, goatee); }
	else if (beard_style == 4) { beard = moustache; }
	c = mix(c, beard_c, beard);

	// --- Cara: solo en la parte delantera ---
	float face = below(dn, 0.38);
	vec2 p = vec2(ax, fn);
	// Ojos: blanco, iris y brillo
	vec2 eye = vec2(0.046, 0.026);
	// El párpado baja desde arriba: el ojo se aplasta hacia su borde inferior
	float bl = blink_amount();
	float open_k = 1.0 - bl * 0.94;
	vec2 eye_c = eye - vec2(0.0, 0.0078 * (1.0 - open_k) * 0.6);
	float white = ellipse(p, eye_c, vec2(0.0135, 0.0078 * open_k)) * face;
	float iris = ellipse(p, eye + vec2(-0.0015, -0.0004), vec2(0.007, 0.007)) * face;
	float shine = ellipse(vec2(x, fn), vec2(sign(x) * (eye.x - 0.002) - 0.003, eye.y + 0.0025), vec2(0.002, 0.002)) * face;
	c = mix(c, vec3(0.96, 0.95, 0.92), white);
	c = mix(c, vec3(0.13, 0.09, 0.07), iris * white);
	c = mix(c, vec3(1.0), shine * white * open_k);
	// Pestañas del ojo cerrado
	float lash = ellipse(p, eye - vec2(0.0, 0.0035), vec2(0.0135, 0.0016)) * face * smoothstep(0.55, 0.9, bl);
	c = mix(c, hair_color * 0.45, lash);
	// Cejas: más bajas hacia el centro (mirada decidida)
	float brow_y = 0.042 + (ax - 0.047) * 0.2;
	float brow = ellipse(vec2(ax, fn - brow_y + 0.044), vec2(0.048, 0.044), vec2(0.017, 0.0042)) * face;
	c = mix(c, hair_color * 0.75, brow);
	// Boca
	float mouth = ellipse(p, vec2(0.0, -0.023), vec2(0.022, 0.0042)) * face;
	c = mix(c, vec3(0.32, 0.1, 0.09), mouth);

	// --- Pelo ---
	if (show_hair && hair_style != 1) {
		float back = smoothstep(0.3, 0.9, dn);
		float line = mix(NOSE_F + 0.074, NOSE_F - 0.03, back);
		if (hair_style == 2) { line += 0.045 * smoothstep(0.04, 0.095, ax) * (1.0 - back * 0.5); }
		float hair = 1.0 - below(f, line);
		// Orejas sin pelo
		float ear = (1.0 - below(ax, 0.086)) * below(fn, 0.05) * (1.0 - below(fn, -0.02))
			* (1.0 - below(dn, 0.3)) * below(dn, 0.72);
		hair *= 1.0 - ear;
		if (hair_style == 3) { hair *= below(ax, 0.024); }
		c = mix(c, hair_color, hair);
	}
	return c;
}

// Pega una zona del atlas de estampados: (u, v) en 0-1 dentro del rectángulo `r` (x, y, w, h).
vec4 decal(vec2 uv, vec4 r) {
	// Derivadas calculadas siempre (fuera del if): si no, en el borde de la zona salta a un
	// mipmap muy borroso y se ve un recuadro gris alrededor del dorsal.
	vec2 st = r.xy + clamp(uv, vec2(0.004), vec2(0.996)) * r.zw;
	vec2 gx = dFdx(uv) * r.zw;
	vec2 gy = dFdy(uv) * r.zw;
	vec4 c = textureGrad(kit_decals, st, gx, gy);
	vec2 e = min(uv, 1.0 - uv);
	return c * step(0.0, min(e.x, e.y)) * smoothstep(0.0, 0.03, min(e.x, e.y));
}

// Color de la camiseta en un punto del tronco (x desde el centro, f altura, dn profundidad: 0 delante)
vec3 kit_base(float x, float ax, float f, float dn) {
	vec3 a = shirt_color;
	vec3 b = shirt_color2;
	bool front = dn < 0.55;
	if (shirt_pattern == 1) { return mix(a, b, below(fract(x / 0.07 + 0.25), 0.5)); }
	if (shirt_pattern == 2) { return mix(a, b, below(fract(f / 0.05), 0.5)); }
	if (shirt_pattern == 3) { return mix(a, b, below(x, 0.0)); }
	if (shirt_pattern == 4) { return mix(a, b, below(abs(x * 1.1 + (f - 0.6)), 0.026)); }
	if (shirt_pattern == 5) {
		float v = abs(f - (0.68 - ax * 0.9));
		return mix(a, b, below(v, 0.012) * (front ? 1.0 : 0.0));
	}
	if (shirt_pattern == 6) { return mix(a, b, below(fract(x / 0.03 + 0.5), 0.18)); }
	if (shirt_pattern == 7) { return mix(a, b, 1.0 - below(f, 0.715 - ax * 0.25)); }
	if (shirt_pattern == 8) {
		// Peto fosforito encima de la camiseta, abierto por los costados
		float bib = below(ax, 0.085) * (1.0 - below(f, SHIRT_BOTTOM + 0.02));
		return mix(a, b, bib);
	}
	if (shirt_pattern == 9) {
		// Chaqueta abierta en V: camisa blanca y corbata (shirt_color2)
		float open = front ? below(ax, (f - 0.6) * 0.42) * (1.0 - below(f, 0.6)) : 0.0;
		vec3 c = mix(a, vec3(0.95), open);
		float tie = front ? below(ax, 0.007 + (0.7 - f) * 0.02) * (1.0 - below(f, 0.59)) : 0.0;
		return mix(c, b, tie * open);
	}
	if (shirt_pattern == 10) { return mix(a, b, mod(floor(x / 0.035 + 50.0) + floor(f / 0.035), 2.0)); }
	if (shirt_pattern == 11) { return mix(a, b, below(abs(f - 0.6), 0.03)); }
	if (shirt_pattern == 12) {
		float band = below(ax, 0.028);
		float edge = below(ax, 0.036) * (1.0 - band);
		return mix(mix(a, vec3(0.95), edge), b, band);
	}
	if (shirt_pattern == 13) { return mix(a, b, 1.0 - below(ax, 0.075)); }
	if (shirt_pattern == 14) {
		float v = f - (0.72 - ax * 1.1);
		return mix(a, b, below(abs(v), 0.03) * (front ? 1.0 : 0.0));
	}
	// 15 banda diagonal ancha (River), 16 degradado, 17 raya diplomática, 18 rombos,
	// 19 bicolor horizontal, 20 franja central ancha (Ajax)
	if (shirt_pattern == 15) { return mix(a, b, below(abs(x * 1.1 + (f - 0.6)), 0.055) * (front ? 1.0 : 0.0)); }
	if (shirt_pattern == 16) { return mix(a, b, smoothstep(0.68, 0.45, f)); }
	if (shirt_pattern == 17) { return mix(a, b, below(fract(x / 0.024 + 0.5), 0.11)); }
	if (shirt_pattern == 18) {
		float u = floor((x + f) / 0.045);
		float v = floor((x - f) / 0.045 + 100.0);
		return mix(a, b, mod(u + v, 2.0));
	}
	if (shirt_pattern == 19) { return mix(a, b, below(f, 0.585)); }
	if (shirt_pattern == 20) { return mix(a, b, below(ax, 0.055) * (1.0 - below(f, 0.43))); }
	// Inspiradas en camisetas famosas, actuales y clásicas:
	// 21 rayas anchas (azulgrana), 22 blanca con ribetes (merengue), 23 polo retro con cuello en V,
	// 24 cuartos (arlequín), 25 hombros de color, 26 rayas que se funden, 27 cruz nórdica, 28 zigzag
	if (shirt_pattern == 21) { return mix(a, b, below(fract(x / 0.105 + 0.25), 0.5)); }
	if (shirt_pattern == 22) {
		// Vivos finos a los costados y por los hombros, y cuello del segundo color
		float side = below(abs(ax - 0.148), 0.01) * (1.0 - below(f, 0.43));
		float shoulder = below(abs(f - (0.735 - ax * 0.18)), 0.008) * (1.0 - below(ax, 0.07));
		float collar = below(ax, 0.075) * (1.0 - below(f, front ? 0.712 : 0.738));
		return mix(a, b, max(max(side, shoulder), collar));
	}
	if (shirt_pattern == 23) {
		// Cuello de polo abierto en V, con tapeta de botones y solapas del segundo color
		float vline = front ? below(abs(ax - (f - 0.645) * 0.75), 0.011) * (1.0 - below(f, 0.645)) : 0.0;
		float flap = front ? below(ax, 0.075) * (1.0 - below(f, 0.705)) * (1.0 - below(ax, (f - 0.645) * 0.75)) : 0.0;
		float back_c = front ? 0.0 : below(ax, 0.08) * (1.0 - below(f, 0.728));
		return mix(a, b, max(max(vline, flap), back_c));
	}
	if (shirt_pattern == 24) { return mix(a, b, abs(below(x, 0.0) - below(f, 0.585))); }
	if (shirt_pattern == 25) { return mix(a, b, 1.0 - below(f, 0.69 - ax * 0.12)); }
	if (shirt_pattern == 26) {
		float st = below(fract(x / 0.07 + 0.25), 0.5);
		return mix(a, b, st * smoothstep(0.72, 0.5, f));
	}
	if (shirt_pattern == 27) {
		float vx = below(abs(x + 0.035), 0.017) * (front ? 1.0 : 0.0) + below(ax, 0.017) * (front ? 0.0 : 1.0);
		float hz = below(abs(f - 0.62), 0.017);
		return mix(a, b, max(vx, hz));
	}
	if (shirt_pattern == 28) {
		float zz = abs(fract(x / 0.06) - 0.5) * 0.05;
		return mix(a, b, below(abs(f - 0.58 - zz), 0.016));
	}
	return a;
}

// Letras que caen sobre una franja de su mismo tono (p. ej. patrocinio sobre la
// banda del pecho): se pintan con el otro color del kit, o blanco/negro.
vec3 ink_fix(vec3 ink, vec3 base) {
	vec3 L = vec3(0.299, 0.587, 0.114);
	float lb = dot(base, L);
	if (abs(dot(ink, L) - lb) > 0.28) { return ink; }
	vec3 alt = abs(dot(shirt_color, L) - lb) > abs(dot(shirt_color2, L) - lb) ? shirt_color : shirt_color2;
	if (abs(dot(alt, L) - lb) < 0.28) { alt = lb > 0.5 ? vec3(0.06) : vec3(0.96); }
	return alt;
}

// Camiseta con sus estampados: escudo y patrocinio delante; apellido y dorsal detrás.
vec3 kit_color(float x, float ax, float f, float dn) {
	vec3 c = kit_base(x, ax, f, dn);
	if (!use_decals || shirt_pattern >= 8 && shirt_pattern <= 9) { return c; }
	vec4 d;
	x *= decal_flip;
	if (dn < 0.55) {
		// Escudo al centro: más grande y con el patrocinio más abajo (en el polo, bajo la V)
		// Tamaños pensados para la cámara del partido (a 6-8 m): más pequeños no se leen
		float sp_f = 0.585;
		if (crest_center || shirt_pattern == 23) {
			float cf = shirt_pattern == 23 ? 0.625 : 0.655;
			d = decal(vec2(x / 0.075 + 0.5, 0.5 - (f - cf) / 0.075), vec4(0.0, 0.0, 0.5, 0.5));
			sp_f = cf - 0.085;
		} else {
			d = decal(vec2((x - 0.05) / 0.068 + 0.5, 0.5 - (f - 0.665) / 0.068), vec4(0.0, 0.0, 0.5, 0.5));
		}
		vec4 sp = decal(vec2(x / 0.2 + 0.5, 0.5 - (f - sp_f) / 0.05), vec4(0.0, 0.5, 1.0, 0.25));
		sp.rgb = ink_fix(sp.rgb, c);
		d = mix(d, sp, sp.a);
	} else {
		d = decal(vec2(0.5 - x / 0.12, 0.5 - (f - 0.6) / 0.12), vec4(0.5, 0.0, 0.5, 0.5));
		d.rgb = ink_fix(d.rgb, c);
		vec4 nm = decal(vec2(0.5 - x / 0.15, 0.5 - (f - 0.693) / 0.0375), vec4(0.0, 0.75, 1.0, 0.25));
		nm.rgb = ink_fix(nm.rgb, c);
		d = mix(d, nm, nm.a);
	}
	return mix(c, d.rgb, d.a);
}


vec3 body_color() {
	float x = body_a.x - 0.5;
	float ax = abs(x);
	float f = body_a.y;
	float dn = (body_b.x - 0.5) / HEAD_DEPTH;
	float t = body_b.y * 3.0 - 0.5;
	vec3 trim = trim_of(shirt_color);

	if (body_w.x > 0.5) {
		// Brazo: manga corta con ribete; antebrazo y mano, piel
		float s_end = long_sleeves ? WRIST_T : SLEEVE_END;
		float sleeve = below(t, s_end);
		float cuff = sleeve * (1.0 - below(t, s_end - 0.06)) * smoothstep(0.8, 0.95, body_w.x);
		bool arm2 = shirt_pattern == 7 || shirt_pattern == 25 || (shirt_pattern == 3 || shirt_pattern == 24) && x < 0.0;
		vec3 arm = arm2 ? shirt_color2 : shirt_color;
		// Puños del segundo color en las clásicas y en la de ribetes
		if (shirt_pattern == 22 || shirt_pattern == 23 || shirt_pattern == 21) { trim = shirt_color2; }
		if (shirt_pattern == 9 || shirt_pattern == 8) { cuff = 0.0; }
		vec3 ac = mix(skin_color, mix(arm, trim, cuff), sleeve);
		if (gloves) {
			// Guante: puño ancho del segundo color y el resto del principal, con la palma
			// algo más oscura (el agarre)
			float g = 1.0 - below(t, WRIST_T - 0.1);
			float band = g * below(t, WRIST_T + 0.08);
			vec3 gc = mix(glove_color, glove_color * 0.72, step(0.5, body_b.x) * 0.6);
			ac = mix(ac, mix(gc, glove_color2, band), g);
		}
		return ac;
	}
	if (body_w.y > 0.5) {
		// Cabeza y cuello; por debajo del cuello de la camiseta, camiseta
		// (más bajo por delante, como el cuello redondo de una camiseta)
		float collar_f = COLLAR_F - 0.03 * below(dn, 0.55);
		return mix(head_color(x, ax, f, dn), kit_color(x, ax, f, dn), below(f, collar_f));
	}
	// Tronco y piernas, de abajo arriba: botas, medias (con ribete), piel, pantalón, camiseta
	vec3 boot = use_sole ? mix(sole_color, boots_color, 1.0 - below(f, 0.013)) : boots_color;
	vec3 c = mix(boot, socks_color, 1.0 - below(f, BOOTS_TOP));
	float sock_band = (1.0 - below(f, SOCKS_TOP - 0.011)) * below(f, SOCKS_TOP);
	c = mix(c, trim_of(socks_color), sock_band);
	c = mix(c, skin_color, 1.0 - below(f, SOCKS_TOP));
	float shorts_bottom = long_pants ? BOOTS_TOP : SHORTS_BOTTOM;
	vec3 shorts = long_pants ? shorts_color : mix(shorts_color, trim_of(shorts_color), below(f, SHORTS_BOTTOM + 0.01));
	if (long_pants) {
		// Pantalón: bajo un poco más oscuro (el dobladillo), raya de la plancha por
		// delante de cada pernera y cinturón bajo la camiseta
		shorts *= mix(1.0, 0.82, below(f, BOOTS_TOP + 0.012));
		float crease = (dn < 0.55 ? 1.0 : 0.0) * below(abs(ax - (0.085 - (f - 0.15) * 0.16)), 0.0025) * below(f, 0.36);
		shorts = mix(shorts, shorts * 0.86, crease);
		shorts = mix(shorts, vec3(0.07, 0.05, 0.04), (1.0 - below(f, SHIRT_BOTTOM - 0.014)) * below(f, SHIRT_BOTTOM + 0.002));
	} else {
		// Pantaloneta: franja lateral del color del ribete (como las de verdad)
		float side = below(abs(ax - (0.14 - (f - 0.25) * 0.19)), 0.005) * (1.0 - below(f, SHORTS_BOTTOM + 0.01));
		shorts = mix(shorts, trim_of(shorts_color), side);
	}
	c = mix(c, shorts, 1.0 - below(f, shorts_bottom));
	c = mix(c, kit_color(x, ax, f, dn), 1.0 - below(f, SHIRT_BOTTOM));
	return c;
}
