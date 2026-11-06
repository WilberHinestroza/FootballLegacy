// Jugador pintado por zonas (piel, equipación, pelo, barba, ojos y boca) a partir de las
// coordenadas que guarda tools/build_player_glb.py. La lógica está en player_body.gdshaderinc.
// Se dibujan las dos caras: la malla está abierta en las perneras y mangas, y por dentro
// (más oscuro, como la sombra del interior de la tela) no debe verse a través.
shader_type spatial;
render_mode cull_disabled;

#include "res://match3d/shaders/player_body.gdshaderinc"

void fragment() {
	if (covered_by_garment()) { discard; }
	ALBEDO = body_color() * (FRONT_FACING ? 1.0 : 0.8);
	// Por dentro de la cabeza (se ve por la boca abierta del modelo): oscuro, como la garganta
	if (!FRONT_FACING && body_a.y > COLLAR_F - 0.06) { ALBEDO = vec3(0.1, 0.035, 0.03); }
	ROUGHNESS = 0.85;
	// Luz de contorno: separa a los jugadores del césped (como en las retransmisiones)
	RIM = 0.15;
	RIM_TINT = 0.6;
}
