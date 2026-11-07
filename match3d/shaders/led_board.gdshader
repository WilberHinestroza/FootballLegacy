shader_type spatial;
// Vallas LED: todas las vallas del estadio son UNA MultiMesh con este material.
// El atlas tiene un anuncio por fila; cada valla muestra la fila (desfase + turno)
// y cada `period` segundos todas pasan al siguiente con un barrido vertical.
// INSTANCE_CUSTOM: x = desfase de la valla, y = largo en metros (rejilla LED).
render_mode unshaded, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float cells = 8.0;     // anuncios que rotan (filas del atlas sin contar la de gol)
uniform float period = 8.0;    // segundos por anuncio (0 = fijo)
uniform float goal_mix = 0.0;  // 0..1: todas las vallas muestran la fila de gol
uniform float brightness = 1.0;

varying vec2 custom;

void vertex() {
	custom = INSTANCE_CUSTOM.xy;
}

vec3 cell_color(float row, vec2 uv) {
	float total = cells + 1.0;
	return texture(atlas, vec2(uv.x, (row + clamp(uv.y, 0.01, 0.99)) / total)).rgb;
}

void fragment() {
	vec2 uv = UV;
	float turn = period > 0.0 ? floor(TIME / period) : 0.0;
	float local = period > 0.0 ? TIME - turn * period : 0.0;
	float cur = mod(custom.x + turn, cells);
	vec3 col = cell_color(cur, uv);
	// Barrido: en el último 0.35 s el siguiente anuncio entra desde arriba
	float wipe = period > 0.0 ? smoothstep(period - 0.35, period, local) : 0.0;
	if (wipe > 0.0) {
		float nxt = mod(cur + 1.0, cells);
		if (uv.y < wipe)
			col = cell_color(nxt, vec2(uv.x, uv.y + 1.0 - wipe));
		else
			col = cell_color(cur, vec2(uv.x, uv.y - wipe));
	}
	// Gol: parpadeo con la fila de gol desplazándose a lo largo de la valla
	if (goal_mix > 0.0) {
		vec3 g = cell_color(cells, vec2(fract(uv.x + TIME * 0.6), uv.y));
		float blink = 0.75 + 0.25 * step(0.5, fract(TIME * 3.0));
		col = mix(col, g * blink, goal_mix);
	}
	// Rejilla de diodos: solo de cerca (se desvanece con la distancia para no hacer moiré)
	vec2 grid = fract(vec2(uv.x * custom.y, uv.y) * 36.0);
	float dots = smoothstep(0.0, 0.25, grid.x) * smoothstep(1.0, 0.75, grid.x)
			* smoothstep(0.0, 0.25, grid.y) * smoothstep(1.0, 0.75, grid.y);
	float near = 1.0 - clamp(fwidth(uv.x * custom.y * 36.0) * 1.5, 0.0, 1.0);
	col *= mix(1.0, 0.72 + 0.28 * dots, near);
	ALBEDO = col * brightness;
}
