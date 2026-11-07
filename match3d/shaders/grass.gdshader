// Césped: franjas de corte alternas, variación con ruido y algo de desgaste en las áreas.
// Coordenadas en el mundo, así que el mismo material sirve para el campo y los alrededores.
shader_type spatial;
render_mode cull_back;

uniform vec3 light_col : source_color = vec3(0.32, 0.68, 0.28);
uniform vec3 dark_col : source_color = vec3(0.25, 0.57, 0.23);
uniform float stripe_width = 4.6667;
uniform float half_length = 28.0;
uniform float stripes_on = 1.0;
uniform float wear = 1.0; // calvas delante de las porterías
uniform float wet = 0.0;  // lluvia: más oscuro y brillante, con charcos

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Franjas con borde suavizado (sin dientes de sierra a lo lejos)
	float x = (wpos.x + half_length) / stripe_width;
	float w = fwidth(x);
	float tri = abs(fract(x * 0.5) * 2.0 - 1.0); // 0..1, cambia de franja en 0.5
	float s = smoothstep(0.5 - w, 0.5 + w, tri) * stripes_on;
	vec3 c = mix(dark_col, light_col, s);
	// Variación: manchas grandes + grano fino
	float n = noise(wpos.xz * 0.25) * 0.5 + noise(wpos.xz * 1.7) * 0.3 + noise(wpos.xz * 11.0) * 0.2;
	c *= 0.88 + n * 0.22;
	// Brillo del corte según desde dónde se mira: las franjas cambian de tono con la cámara
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
	float bend = (s * 2.0 - 1.0) * stripes_on; // hacia dónde está tumbada la hierba
	c *= 1.0 + bend * clamp(vdir.x * 1.6, -1.0, 1.0) * 0.06;
	// Hebras finas cerca de la cámara (se apagan a lo lejos para que no titilen)
	float fade = clamp(1.0 - length(fwidth(wpos.xz)) * 18.0, 0.0, 1.0);
	float blade = noise(vec2(wpos.x * 38.0, wpos.z * 7.0)) * 0.6 + noise(wpos.xz * 23.0) * 0.4;
	c *= 1.0 + (blade - 0.5) * 0.16 * fade;
	// Desgaste delante de cada portería
	float dx = half_length - abs(wpos.x);
	float worn = wear * exp(-pow(dx - 1.5, 2.0) * 0.12 - wpos.z * wpos.z * 0.05);
	c = mix(c, vec3(0.36, 0.44, 0.22), clamp(worn * (0.3 + n * 0.5), 0.0, 0.35));
	// Mojado: la hierba se oscurece y refleja la luz; en las zonas más bajas, charcos
	float puddle = smoothstep(0.66, 0.8, noise(wpos.xz * 0.13 + 7.0)) * wet;
	c *= mix(1.0, 0.74, wet) * mix(1.0, 0.8, puddle);
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.95, 0.6, wet), 0.18, puddle);
	SPECULAR = mix(0.2, 0.38, wet);
}
