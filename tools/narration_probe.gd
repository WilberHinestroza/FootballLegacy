extends Node

## Prueba dirigida de la narración enriquecida (Parte 91i, pedido de
## Wilber: "narración enriquecida e inmersiva"): _ambient_line() (frases
## ambiente con variantes, Match.gd) y _outcome_title() (título por
## acción en vez de "ACERTASTE"/"FALLASTE" genérico). Métodos puros —
## nunca disparan _ready(), así que no hace falta instanciar la escena
## real (mismo criterio que MatchNationalFixtureProbe).
##   godot --headless res://tools/NarrationProbe.tscn

func _ready() -> void:
	var problems: int = 0
	var m = (load("res://scenes/Match/Match.gd") as GDScript).new()

	# --- _ambient_line(): determinista, con variedad real ---
	var seen: Dictionary = {}
	for minute in range(1, 90):
		var line: String = m._ambient_line("possession_home", minute)
		seen[line] = true
		if line == "":
			print("FALLA: _ambient_line devolvió vacío en el minuto %d" % minute)
			problems += 1
	print("_ambient_line('possession_home') variantes distintas en 89 minutos: %d (esperado > 1)" % seen.size())
	if seen.size() <= 1:
		problems += 1
	var repeat_ok: bool = m._ambient_line("possession_home", 30) == m._ambient_line("possession_home", 30)
	print("determinismo (mismo minuto = misma frase): %s" % repeat_ok)
	if not repeat_ok:
		problems += 1
	var fallback: String = m._ambient_line("kind_que_no_existe", 10)
	print("fallback de kind desconocido: '%s'" % fallback)
	if fallback == "":
		problems += 1

	# --- las 28 claves de AMBIENT_KINDS (MatchEngine) tienen su
	# contraparte en AMBIENT_TEMPLATES (Match.gd) — que no se cuele un
	# kind nuevo del motor sin su texto ---
	for k in MatchEngine.AMBIENT_KINDS:
		if not m.AMBIENT_TEMPLATES.has(k):
			print("FALLA: AMBIENT_KINDS tiene '%s' pero AMBIENT_TEMPLATES no" % k)
			problems += 1
	print("AMBIENT_KINDS (%d) todos con texto en Match.AMBIENT_TEMPLATES" % MatchEngine.AMBIENT_KINDS.size())

	# --- _outcome_title(): las 24 acciones de decisión tienen texto propio,
	# ninguna cae al genérico "ACERTASTE"/"FALLASTE" ---
	var all_kinds: Array = MatchEngine.DECISION_LABELS.keys()
	var generic_count: int = 0
	for k in all_kinds:
		var ok_title: String = m._outcome_title(String(k), true)
		var fail_title: String = m._outcome_title(String(k), false)
		if ok_title == "ACERTASTE" or fail_title == "FALLASTE":
			generic_count += 1
			print("  (sin texto propio: %s)" % k)
	print("acciones con texto genérico de respaldo: %d de %d" % [generic_count, all_kinds.size()])
	if generic_count > 0:
		print("FALLA: hay acciones en DECISION_LABELS sin entrada en _OUTCOME_FLAVOR")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
