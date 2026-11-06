// Flashes de cámaras en la grada: cada instancia destella de vez en cuando
// (mucho más al marcar un gol). Cuadradito que siempre mira a la cámara.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float excitement = 0.0;
uniform float strength = 1.0;

varying float flash;

void vertex() {
	float id = float(INSTANCE_ID);
	float phase = fract(sin(id * 91.17) * 43758.5453);
	float rate = mix(0.12, 0.9, excitement) * (0.6 + phase);
	float f = fract(TIME * rate + phase * 7.0);
	flash = (1.0 - smoothstep(0.0, 0.025, f)) * (0.5 + 0.5 * excitement);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= flash;
}

void fragment() {
	vec2 c = UV - 0.5;
	float glow = max(1.0 - length(c) * 2.0, 0.0);
	ALBEDO = vec3(1.0, 0.97, 0.9) * glow * glow * flash * strength * 3.0;
}
