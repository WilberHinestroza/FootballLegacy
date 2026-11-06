// Igual que player_zones.gdshader pero semitransparente:
// se usa cuando el jugador tapa la jugada a la cámara.
shader_type spatial;
render_mode depth_draw_always, cull_disabled;

#include "res://match3d/shaders/player_body.gdshaderinc"

uniform float alpha = 0.25;

void fragment() {
	if (under_pants()) { discard; }
	ALBEDO = body_color() * (FRONT_FACING ? 1.0 : 0.8);
	// Por dentro de la cabeza (se ve por la boca abierta del modelo): oscuro, como la garganta
	if (!FRONT_FACING && body_a.y > COLLAR_F - 0.06) { ALBEDO = vec3(0.1, 0.035, 0.03); }
	ROUGHNESS = 0.85;
	ALPHA = alpha;
}
