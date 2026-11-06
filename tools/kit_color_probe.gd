extends SceneTree

## Prueba dirigida del bug real reportado por Wilber: "revisa las
## camisetas de las selecciones y sus colores" — antes CountryFlags.
## team_color() sacaba un color inventado por hash para TODO país, sin
## excepción (Argentina podía salir de cualquier color menos celeste).
## Confirma que las selecciones más reconocibles ahora dan su color real,
## y que un país sin entrada en REAL_KIT_COLOR sigue con el hash
## determinista de siempre (sin romper nada).
##   godot --headless -s tools/kit_color_probe.gd

func _init():
	var ok: bool = true
	var expected := {
		"Argentina": "75aadb", "Brasil": "ffcc00", "Alemania": "ffffff",
		"Francia": "0055a4", "Italia": "0038a8", "España": "c60b1e",
	}
	for country in expected:
		var col: Color = CountryFlags.team_color(country)
		var hex: String = col.to_html(false)
		print("%s: #%s (esperado #%s)" % [country, hex, expected[country]])
		if hex != String(expected[country]):
			print("FALLA: %s no dio su color real" % country)
			ok = false

	# País sin entrada en REAL_KIT_COLOR: debe seguir siendo determinista
	# (mismo país, mismo color siempre) vía el hash de toda la vida.
	var c1: Color = CountryFlags.team_color("Andorra")
	var c2: Color = CountryFlags.team_color("Andorra")
	print("Andorra (sin color real curado): #%s == #%s ? %s" % [c1.to_html(false), c2.to_html(false), c1 == c2])
	if c1 != c2:
		print("FALLA: el color de un país sin curar debería ser determinista")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
