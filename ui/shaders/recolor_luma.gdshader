shader_type canvas_item;

// Recolorea una textura tratándola como máscara de luminancia: la parte
// oscura del sprite -> tono oscuro del color pedido, la clara -> tono
// claro. Sirve para teñir a CUALQUIER color partes que ya vienen con un
// color propio (pelo/piel/ropa del Avatar Mixer, capas de escudo), cosa
// que `modulate` (multiplicación) no puede hacer.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gain = 1.55;
uniform float ambient = 0.14;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c = tint.rgb * clamp(l * gain + ambient, 0.0, 1.25);
	COLOR = vec4(c, src.a * tint.a);
}
