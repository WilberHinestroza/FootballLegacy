extends Node

## Prueba dirigida del ícono del árbitro en el popup de tarjeta amarilla/
## roja (pedido de Wilber: arte propio del árbitro sacando la tarjeta,
## fondo blanco ya quitado). _card_icon() no toca ningún nodo @onready
## (solo arma un TextureRect nuevo con los PNG precargados), así que se
## puede llamar directo sobre el script suelto — mismo criterio que el
## resto de probes de Match.gd en esta sesión (Match.tscn no se puede
## instanciar de verdad sin un MatchEngine real corriendo).
##   godot --headless res://tools/RefereeCardIconProbe.tscn

func _ready() -> void:
	var ok: bool = true
	var m = (load("res://scenes/Match/Match.gd") as GDScript).new()

	var yellow: Control = m._card_icon(false)
	var red: Control = m._card_icon(true)

	for pair in [["amarilla", yellow, "res://assets/characters/referee/referee_yellow_card.png"],
			["roja", red, "res://assets/characters/referee/referee_red_card.png"]]:
		var label: String = pair[0]
		var rect: TextureRect = pair[1]
		var expected_path: String = pair[2]
		if rect == null or not (rect is TextureRect):
			print("FALLA (%s): _card_icon no devolvió un TextureRect" % label)
			ok = false
			continue
		if rect.texture == null:
			print("FALLA (%s): TextureRect sin textura" % label)
			ok = false
			continue
		var actual_path: String = rect.texture.resource_path
		print("%s: textura=%s tamaño_mínimo=%s" % [label, actual_path, rect.custom_minimum_size])
		if actual_path != expected_path:
			print("FALLA (%s): esperaba %s, salió %s" % [label, expected_path, actual_path])
			ok = false
		var expected_h: float = float(m._REFEREE_ICON_HEIGHT) # no hardcodear el número: ya bajó una vez (130->92, "un tris más pequeño")
		if absf(rect.custom_minimum_size.y - expected_h) > 0.1:
			print("FALLA (%s): alto esperado %.1f, salió %.1f" % [label, expected_h, rect.custom_minimum_size.y])
			ok = false
		if rect.custom_minimum_size.x <= 0.0 or rect.custom_minimum_size.x >= expected_h:
			print("FALLA (%s): ancho fuera de rango razonable (el árbitro es angosto, retrato) — salió %.1f" % [label, rect.custom_minimum_size.x])
			ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
