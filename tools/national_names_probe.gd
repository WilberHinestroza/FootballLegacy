extends Node

## Prueba dirigida de nombres realistas por país en el relleno sintético
## de selecciones (pedido de Wilber: "investiga nombres y apellidos de
## esos países para crearlos y que sea más realista"). Verifica:
##   1. Countries.ALL: cuántos países quedan sin región explícita en
##      NationalNames.COUNTRY_REGION (caen al pool genérico de siempre —
##      no es un error, pero se imprime para poder revisar cobertura).
##   2. WorldFactory.synthetic_filler(..., country) devuelve un nombre de
##      la región correcta (comparando contra NationalNames.NAMES) Y deja
##      `p.country` seteado (antes NUNCA se seteaba en el relleno de
##      selección — bug real corregido de paso).
##   3. Sin `country` (relleno de plantel de CLUB, comportamiento de
##      siempre) sigue sin tocar `p.country` ni el pool internacional.
## No toca slot_1/slot_2 (no usa SaveManager en absoluto, todo puro).
##   godot --headless res://tools/NationalNamesProbe.tscn

func _ready() -> void:
	var ok: bool = true

	# --- 1) Cobertura de Countries.ALL ---
	var uncovered: Array = []
	for c in Countries.ALL:
		if not NationalNames.COUNTRY_REGION.has(c):
			uncovered.append(c)
	print("Countries.ALL: %d países, %d sin región explícita (caen a 'generic')" % [Countries.ALL.size(), uncovered.size()])
	if not uncovered.is_empty():
		print("  sin región: %s" % ", ".join(uncovered))

	# --- 2) Nombre + country correctos para varios países de prueba ---
	var cases: Array = [
		["Nigeria", "africa_oeste_a"], ["Japón", "japones"], ["Brasil", "brasil"],
		["Francia", "francia"], ["Argentina", "hispano"], ["Vietnam", "vietnamita"],
		["País Que No Existe", "generic"],
	]
	for c in cases:
		var country: String = c[0]
		var expected_region: String = c[1]
		var p := WorldFactory.synthetic_filler("probe:%s" % country, "MF", 60, country)
		var region: String = String(NationalNames.COUNTRY_REGION.get(country, "generic"))
		var pool: Dictionary = NationalNames.NAMES.get(region, {})
		var name_ok: bool = true
		if not pool.is_empty():
			var parts: PackedStringArray = p.player_name.split(" ", false, 1)
			var first_ok: bool = (pool["first"] as Array).has(parts[0])
			name_ok = first_ok
		print("%s (región=%s): nombre='%s' country='%s'" % [country, region, p.player_name, p.country])
		if region != expected_region:
			print("FALLA: %s esperaba región '%s', salió '%s'" % [country, expected_region, region])
			ok = false
		if p.country != country:
			print("FALLA: %s no dejó p.country seteado (salió '%s')" % [country, p.country])
			ok = false
		if not name_ok:
			print("FALLA: %s: el nombre generado no viene del pool esperado" % country)
			ok = false

	# --- 3) Relleno de CLUB (sin country) no cambia de comportamiento ---
	var club_p := WorldFactory.synthetic_filler("probe:club", "MF", 60)
	print("Relleno de club (sin country): nombre='%s' country='%s'" % [club_p.player_name, club_p.country])
	if club_p.country != "":
		print("FALLA: el relleno de CLUB no debería tocar country")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
