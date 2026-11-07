// Público: cada persona (instancia del MultiMesh) bota con su propio ritmo.
// `excitement` sube al marcar un gol y todo el estadio salta y levanta los brazos.
// La malla (FieldBuilder._fan_mesh) marca en UV.x la pieza (0 camiseta, 1 piel,
// 2 pelo) y en UV.y el brazo (-1 izquierdo, 1 derecho), que gira en el hombro.
shader_type spatial;

uniform float excitement = 0.0;
// La ola: 0 = nada, 1 = la ola da vueltas al estadio (se levantan al pasar).
uniform float wave = 0.0;

varying vec3 tint;

float h1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	float id = float(INSTANCE_ID);
	float phase = h1(id) * 6.2831;
	float speed = 2.0 + fract(id * 0.618) * 2.0 + excitement * 5.0;
	float amp = 0.03 + excitement * 0.25;
	float hop = max(sin(TIME * speed + phase), 0.0) * amp;
	// Un poco de variedad de talla
	float tall = 0.92 + h1(id + 3.1) * 0.16;
	VERTEX *= vec3(0.94 + h1(id + 7.7) * 0.14, tall, 1.0);
	// La ola: un frente que gira alrededor del centro del campo
	float up = 0.0;
	if (wave > 0.001) {
		vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float ang = atan(o.z, o.x) / 6.2831 + 0.5;
		float d = fract(ang - TIME * 0.09);
		d = min(d, 1.0 - d);
		up = smoothstep(0.045, 0.0, d) * wave;
	}
	// Brazos: casi quietos (algún aplauso suelto); con gol, la mayoría arriba
	// agitándolos; con la ola, todos arriba al pasar.
	float side = UV.y;
	if (abs(side) > 0.5) {
		float raiser = step(0.25, h1(id + 1.3));
		float lift = clamp(excitement * raiser * 1.3 + up, 0.0, 1.0);
		float a = mix(0.05 + 0.06 * sin(TIME * 3.0 + phase), 2.65 + 0.25 * sin(TIME * 7.0 + phase + side), lift);
		a *= sign(side);
		vec2 piv = vec2(sign(side) * 0.2, 0.42 * tall);
		vec2 v = VERTEX.xy - piv;
		float c = cos(a);
		float s = sin(a);
		VERTEX.xy = piv + vec2(c * v.x - s * v.y, s * v.x + c * v.y);
		VERTEX.z += lift * 0.05;
	}
	VERTEX.y += hop + up * 0.3;
	// Color de cada pieza
	vec3 skins[4] = {vec3(0.96, 0.8, 0.66), vec3(0.85, 0.64, 0.47), vec3(0.6, 0.42, 0.29), vec3(0.38, 0.25, 0.17)};
	vec3 skin = skins[int(h1(id + 0.377) * 3.99)];
	vec3 hairs[5] = {vec3(0.06, 0.05, 0.05), vec3(0.2, 0.12, 0.07), vec3(0.42, 0.27, 0.13), vec3(0.78, 0.62, 0.32), vec3(0.62, 0.6, 0.58)};
	float hr = h1(id + 5.5);
	vec3 hair = hr < 0.12 ? COLOR.rgb : (hr < 0.2 ? skin : hairs[int(h1(id + 9.1) * 4.99)]);
	float part = UV.x;
	// La frente (UV.x 2 con UV.y 0.5) es piel salvo con gorra
	if (part > 1.5 && UV.y > 0.25 && UV.y < 0.75) {
		hair = hr < 0.12 ? COLOR.rgb : skin;
	}
	tint = part < 0.5 ? COLOR.rgb : (part < 1.5 ? skin : hair);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
