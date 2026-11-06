// Banderas del público y de córner: la tela ondea (más cuanto más lejos del mástil)
// y los aficionados la agitan más al celebrar. UV.x < 0 = mástil (no se mueve).
shader_type spatial;
render_mode cull_disabled;

uniform float excitement = 0.0;
uniform vec3 stripe_color : source_color = vec3(1.0);
uniform float wave = 1.0;
uniform float swing_amount = 1.0;

varying float u;
varying vec3 base_col;

void vertex() {
	float id = float(INSTANCE_ID);
	float phase = fract(sin(id * 78.233) * 43758.5453) * 6.2831;
	u = UV.x;
	base_col = COLOR.rgb;
	if (UV.x >= 0.0) {
		float speed = 5.0 + excitement * 4.0;
		float amp = (0.07 + excitement * 0.08) * wave;
		VERTEX.z += sin(TIME * speed - UV.x * 5.0 + phase) * amp * UV.x * 1.6;
		VERTEX.y += cos(TIME * speed * 0.7 - UV.x * 4.0 + phase) * 0.03 * UV.x * wave;
	}
	// Los aficionados agitan la bandera: el conjunto se balancea sobre la mano
	float swing = sin(TIME * (2.0 + excitement * 3.0) + phase) * (0.12 + excitement * 0.35) * swing_amount;
	float c = cos(swing);
	float s = sin(swing);
	VERTEX.xy = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
}

void fragment() {
	if (u < 0.0) {
		ALBEDO = vec3(0.75);
	} else {
		// Dos colores: franja central clara
		float band = step(0.36, UV.y) * step(UV.y, 0.64);
		ALBEDO = mix(base_col, stripe_color, band);
	}
	ROUGHNESS = 0.85;
}
