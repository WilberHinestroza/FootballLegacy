shader_type canvas_item;

// Ola lenta de brillo sobre la multitud (el "público que se mueve"),
// barata para móvil: solo modula el color por seno de UV + TIME.
uniform float speed = 0.6;
uniform float amp = 0.22;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float w = 0.78
		+ amp * 0.5 * sin(UV.x * 9.0 + TIME * speed)
		+ amp * 0.5 * sin(UV.y * 22.0 - TIME * speed * 0.7);
	COLOR = vec4(c.rgb * w, c.a);
}
