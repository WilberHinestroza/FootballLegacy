extends Node

## Prueba dirigida de la vista de detalle nueva en Selections.gd (pedido
## de Wilber: botones para ver cada competición — Mundial y copas
## continentales — con su cuadro, goleador y asistidor). Instancia el
## SCRIPT (no la escena — Selections.gd no tiene class_name, ver la nota
## de siempre sobre Match.gd) y asigna `content_box` a mano: ninguno de
## los métodos probados toca otro nodo @onready (back_button/scroll solo
## se usan en _ready(), ver grep hecho antes de escribir esto), mismo
## criterio que PreMatchNationalFixtureProbe/NarrationProbe.
##   godot --headless res://tools/SelectionsDetailProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	var season_start: int = 0
	var year: int = WorldCupEngine.WC_BASE_YEAR
	var final_day: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL
	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": year, "season_start_epoch_day": season_start, "current_epoch_day": final_day}
	WorldTickEngine.current_epoch_day = final_day

	var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
	var champion: String = String(wc.get("champion_country", ""))
	if champion == "":
		print("PROBE FAIL (mundial no decidido en el día de prueba, ver NationalTopPerformersProbe)")
		get_tree().quit(1)
		return

	var p := PlayerData.new()
	p.player_name = "Probe Selecciones"
	p.country = champion
	p.national_team_status = "regular"
	p.caps = 12
	p.international_goals = 4
	p.international_assists = 2

	var sel_script: GDScript = load("res://scenes/Selections/Selections.gd")
	var sel = sel_script.new()
	sel._player = p
	sel.content_box = VBoxContainer.new()
	# content_box VIVO (hijo de este probe, que sí está en el árbol) para
	# que cualquier Pager.new() que se agregue adentro dispare su propio
	# _ready() de verdad — hace falta para el chequeo nuevo del Pager de
	# rondas del cuadro de eliminación (necesita _rows real, no null).
	add_child(sel.content_box)

	var ok: bool = true

	# --- Detalle del Mundial: las 3 pestañas, sin crashear, con contenido ---
	sel._detail_kind = "worldcup"
	for tab in ["bracket", "scorers", "assists"]:
		sel._detail_tab = tab
		for c in sel.content_box.get_children():
			c.queue_free()
		sel._render_detail()
		var n: int = sel.content_box.get_child_count()
		print("worldcup/%s: %d nodos en content_box" % [tab, n])
		if n < 2: # header + al menos un cuerpo
			print("FALLA: pestaña '%s' del Mundial no agregó contenido" % tab)
			ok = false

	# --- Cuadro de eliminación paginado por ronda (pedido de Wilber: "no
	# hay scroll para ver lo que sigue... ya en los brackets" — un Mundial
	# de 32 apilaba las 5 rondas, 31 partidos, en un solo cuadro sin
	# paginar). Confirma que el Pager de rondas conoce TODAS las rondas
	# pero solo RENDERIZA la de la página actual (1 ronda a la vez). ---
	sel._detail_tab = "bracket"
	for c in sel.content_box.get_children():
		c.queue_free()
	sel._render_detail()
	var round_pager: Pager = _find_pager(sel.content_box, 2) # la 2ª Pager: 1ª es la de grupos
	if round_pager == null:
		print("FALLA: no se encontró el Pager de rondas del cuadro de eliminación")
		ok = false
	else:
		var total_rounds: int = round_pager._items.size()
		var rows_shown: int = round_pager._rows.get_child_count()
		print("cuadro de eliminación: %d rondas totales, %d renderizadas de una" % [total_rounds, rows_shown])
		if total_rounds < 2:
			print("FALLA: se esperaban varias rondas de eliminación (Mundial de 32)")
			ok = false
		if rows_shown != 1:
			print("FALLA: el Pager de rondas debería mostrar UNA ronda por página, mostró %d" % rows_shown)
			ok = false

	# --- Toggle Tabla/Fixtures de la fase de grupos (pedido de Wilber:
	# "agregales sus fixtures y sus brackets") — confirma que WorldCupEngine
	# ya dejó el resultado escrito en cada fixture de grupo (sin recalcular
	# nada aparte) y que la vista de fixtures arma contenido real. ---
	var wc_groups: Array = wc.get("groups", []) as Array
	var g0_fixtures: Array = []
	if wc_groups.is_empty():
		print("FALLA: Mundial resuelto sin grupos, no se puede probar fixtures")
		ok = false
	else:
		g0_fixtures = wc_groups[0].get("fixtures", []) as Array
		var any_result: bool = false
		for fx in g0_fixtures:
			if fx.get("result", null) != null:
				any_result = true
				break
		print("Grupo A del Mundial: %d fixtures, ¿alguno con resultado ya escrito?=%s" % [g0_fixtures.size(), any_result])
		if not any_result:
			print("FALLA: la fase de grupos ya terminó pero ningún fixture quedó con 'result'")
			ok = false

	sel._detail_kind = "worldcup"
	sel._detail_tab = "bracket"
	sel._detail_group_view = "fixtures"
	for c in sel.content_box.get_children():
		c.queue_free()
	sel._render_detail()
	var fx_view_n: int = sel.content_box.get_child_count()
	print("worldcup/fixtures (vista de grupos): %d nodos en content_box" % fx_view_n)
	if fx_view_n < 2:
		print("FALLA: la vista de fixtures del Mundial no agregó contenido")
		ok = false
	sel._detail_group_view = "table"

	# --- Fechas reales en fixtures/bracket (pedido de Wilber: "y las
	# fechas de los partidos?") — _short_date() no debe devolver vacío
	# para un epoch_day real, y los encabezados deben mostrarlo. ---
	var date_txt: String = sel._short_date(int(g0_fixtures[0].get("epoch_day", 0))) if not g0_fixtures.is_empty() else ""
	print("_short_date() de un fixture de grupo real: '%s'" % date_txt)
	if date_txt == "":
		print("FALLA: _short_date no devolvió una fecha para un epoch_day real")
		ok = false
	if not wc.get("rounds", []).is_empty():
		var rnd0: Dictionary = (wc.get("rounds", []) as Array)[0]
		var round_date: String = sel._short_date(int(rnd0.get("epoch_day", 0)))
		print("_short_date() de la primera ronda del cuadro: '%s'" % round_date)
		if round_date == "":
			print("FALLA: la ronda del cuadro no trajo epoch_day/fecha")
			ok = false

	# --- Detalle de copa continental (aunque no tenga campeón este año/seed,
	# no debe crashear — solo debe mostrar el aviso de "sin datos") ---
	sel._detail_kind = "national_cup"
	sel._detail_confederation = "CONMEBOL"
	sel._detail_tab = "bracket"
	for c in sel.content_box.get_children():
		c.queue_free()
	sel._render_detail()
	print("national_cup/CONMEBOL bracket: %d nodos en content_box" % sel.content_box.get_child_count())
	if sel.content_box.get_child_count() < 1:
		print("FALLA: detalle de copa continental no agregó ni el header")
		ok = false

	# --- Pantalla principal completa (home): confirmar que arma sin
	# crashear con los botones nuevos de "abrir detalle" ---
	sel._detail_kind = ""
	sel._detail_confederation = ""
	for c in sel.content_box.get_children():
		c.queue_free()
	sel._render()
	var home_n: int = sel.content_box.get_child_count()
	print("home: %d nodos en content_box" % home_n)
	if home_n < 4:
		print("FALLA: pantalla principal quedó con muy poco contenido")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)

## Busca recursivamente el N-ésimo nodo Pager bajo `root` (orden de
## aparición) — para agarrar puntualmente el Pager de rondas del cuadro
## de eliminación sin depender de un nombre de nodo fijo (Pager.new() no
## le pone ninguno).
func _find_pager(root: Node, nth: int) -> Pager:
	var found: Array = []
	_collect_pagers(root, found)
	if found.size() < nth:
		return null
	return found[nth - 1]

func _collect_pagers(node: Node, out: Array) -> void:
	if node is Pager:
		out.append(node)
	for c in node.get_children():
		_collect_pagers(c, out)
