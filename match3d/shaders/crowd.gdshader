// Público: cada persona (instancia del MultiMesh) bota con su propio ritmo.
// `excitement` sube al marcar un gol y todo el estadio salta.
shader_type spatial;

uniform float excitement = 0.0;
// La ola: 0 = nada, 1 = la ola da vueltas al estadio (se levantan al pasar).
uniform float wave = 0.0;

varying vec3 tint;

void vertex() {
	float id = float(INSTANCE_ID);
	float phase = fract(sin(id * 12.9898) * 43758.5453) * 6.2831;
	float speed = 2.0 + fract(id * 0.618) * 2.0 + excitement * 5.0;
	float amp = 0.03 + excitement * 0.25;
	float hop = max(sin(TIME * speed + phase), 0.0) * amp;
	VERTEX.y += hop;
	// La ola: un frente que gira alrededor del centro del campo
	if (wave > 0.001) {
		vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float ang = atan(o.z, o.x) / 6.2831 + 0.5;
		float d = fract(ang - TIME * 0.09);
		d = min(d, 1.0 - d);
		float up = smoothstep(0.045, 0.0, d) * wave;
		VERTEX.y += up * 0.3;
		hop += up * 0.3;
		if (VERTEX.y > 0.25 + up * 0.3) {
			VERTEX.y += up * 0.22; // brazos arriba
		}
	}
	// Brazos arriba al celebrar: estira un poco la parte alta
	if (VERTEX.y > 0.25) {
		VERTEX.y += excitement * 0.12 * (0.5 + 0.5 * sin(TIME * 6.0 + phase));
	}
	// Cabeza (parte alta de la malla): tono de piel según la persona
	vec3 skins[4] = {vec3(0.96, 0.8, 0.66), vec3(0.85, 0.64, 0.47), vec3(0.6, 0.42, 0.29), vec3(0.38, 0.25, 0.17)};
	tint = VERTEX.y > 0.52 + hop ? skins[int(fract(id * 0.377) * 3.99)] : COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
}
