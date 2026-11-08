extends Node

## Prueba dirigida del pedido de Wilber: "agrega el botón de ver fixture,
## goleador y asistencias de cada competición o eliminatoria de
## selecciones de cada continente" — la parte de ELIMINATORIA
## específicamente (Mundial/copa continental ya se probaron en Partes
## 91k/l). Confirma los 2 formatos de QualifyingEngine:
##   - "tabla única" (CONMEBOL/CONCACAF): TopPerformersEngine.
##     compute_national_tournament() ahora también suma resolved["fixtures"].
##   - "grupos" (UEFA/AFC/CAF): ya funcionaba (mismo shape que Mundial/
##     copas), se confirma que sigue andando.
## Y que Selections.gd arma la vista de detalle ("qualifying") sin
## crashear para ambos formatos, con su toggle Tabla/Fixtures.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/QualifyingPerformersProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0}
	# Bastante avanzado el ciclo de 700 días (arranca ~2 años antes del Mundial, Parte 93).
	WorldTickEngine.current_epoch_day = 100
	WorldTickEngine.current_epoch_day = WorldTickEngine._international_cycle_start() + 400

	var ok: bool = true

	# --- 1) Formato "tabla única": CONMEBOL ---
	var conmebol: Dictionary = WorldTickEngine.national_qualifying_for("CONMEBOL")
	print("CONMEBOL: formato=%s, %d fixtures" % [conmebol.get("format", "?"), (conmebol.get("fixtures", []) as Array).size()])
	if String(conmebol.get("format", "")) != "table":
		print("FALLA: se esperaba formato 'table' para CONMEBOL")
		ok = false
	var conmebol_perf: Dictionary = WorldTickEngine.top_performers_for_qualifying("CONMEBOL")
	var conmebol_scorers: Array = conmebol_perf.get("scorers", [])
	print("CONMEBOL goleadores: %d filas (top: %s)" % [conmebol_scorers.size(), conmebol_scorers[0] if not conmebol_scorers.is_empty() else "-"])
	if conmebol_scorers.is_empty():
		print("FALLA: CONMEBOL debería tener goleadores con 400 días de eliminatoria jugada")
		ok = false

	# --- 2) Formato "grupos": UEFA ---
	var uefa: Dictionary = WorldTickEngine.national_qualifying_for("UEFA")
	print("UEFA: formato=%s, %d grupos" % [uefa.get("format", "?"), (uefa.get("groups", []) as Array).size()])
	if String(uefa.get("format", "")) != "groups":
		print("FALLA: se esperaba formato 'groups' para UEFA")
		ok = false
	var uefa_perf: Dictionary = WorldTickEngine.top_performers_for_qualifying("UEFA")
	var uefa_scorers: Array = uefa_perf.get("scorers", [])
	print("UEFA goleadores: %d filas (top: %s)" % [uefa_scorers.size(), uefa_scorers[0] if not uefa_scorers.is_empty() else "-"])
	if uefa_scorers.is_empty():
		print("FALLA: UEFA debería tener goleadores con 400 días de eliminatoria jugada")
		ok = false

	# --- 3) Selections.gd: vista de detalle "qualifying" para ambos formatos ---
	var p := PlayerData.new()
	p.player_name = "Probe Eliminatoria"
	p.country = "Argentina"
	var sel_script: GDScript = load("res://scenes/Selections/Selections.gd")
	var sel = sel_script.new()
	sel._player = p
	sel.content_box = VBoxContainer.new()
	add_child(sel.content_box) # vivo, para que los Pager internos anden bien (ver SelectionsDetailProbe)

	for pair in [["CONMEBOL", "table"], ["UEFA", "groups"]]:
		var conf: String = pair[0]
		var fmt: String = pair[1]
		for tab in ["bracket", "scorers", "assists"]:
			sel._detail_kind = "qualifying"
			sel._detail_confederation = conf
			sel._detail_tab = tab
			sel._detail_group_view = "table"
			for c in sel.content_box.get_children():
				c.queue_free()
			sel._render_detail()
			var n: int = sel.content_box.get_child_count()
			print("qualifying/%s (%s)/%s: %d nodos" % [conf, fmt, tab, n])
			if n < 2:
				print("FALLA: %s/%s no agregó contenido" % [conf, tab])
				ok = false

	# Toggle Fixtures, ambos formatos.
	for conf in ["CONMEBOL", "UEFA"]:
		sel._detail_kind = "qualifying"
		sel._detail_confederation = conf
		sel._detail_tab = "bracket"
		sel._detail_group_view = "fixtures"
		for c in sel.content_box.get_children():
			c.queue_free()
		sel._render_detail()
		var nf: int = sel.content_box.get_child_count()
		print("qualifying/%s fixtures: %d nodos" % [conf, nf])
		if nf < 2:
			print("FALLA: %s en modo fixtures no agregó contenido" % conf)
			ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
