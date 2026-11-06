extends Node

## Prueba dirigida: "en el calendario pinta solo el día de inicio y el día
## final de la ventana de fichajes" — antes _event_for_day() pintaba los
## 21 días completos de CUALQUIERA de las 2 ventanas (verano/invierno) con
## el mismo rótulo genérico "Ventana de fichajes". Ahora solo el día de
## inicio y el de cierre de cada una.
##
## BUG REAL encontrado con una captura de Wilber ("muestra el inicio pero
## no el final"): el día de CIERRE (offset 21, múltiplo de 7) cae SIEMPRE
## el mismo día de la semana que el de inicio — y los amistosos de
## pretemporada se programan semanales, así que el cierre coincidía
## SIEMPRE con un amistoso que lo tapaba (user_fixture_on() devolvía el
## amistoso antes de llegar al chequeo de la ventana). Este probe arma una
## TEMPORADA REAL (con amistosos de verdad, no el mundo vacío del primer
## intento) para reproducir la colisión.
##   godot --headless res://tools/CalendarMarketWindowProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var first_league: LeagueData = world.get("leagues", [])[0]
	var clubs: Array = world.get("clubs_by_league", {}).get(first_league.league_id, [])
	var club_id: String = clubs[0].club_id

	var p := PlayerData.new()
	p.player_name = "Probe Mercado"
	p.club_id = club_id
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)
	var season: Dictionary = SeasonCalendar.build_season(world, first_league.league_id, 0, 2026, club_id, world_seed)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

	var cal_script: GDScript = load("res://scenes/Calendar/Calendar.gd")
	var cal = cal_script.new()
	cal._club_id = club_id
	cal._today_epoch_day = 999999
	cal._nat_country = ""

	var w: int = SeasonCalendar.TRANSFER_WINDOW_DAYS
	var mid: int = SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	var ok: bool = true

	# Confirma la PRECONDICIÓN del bug: el día de cierre (21) tiene de
	# verdad un amistoso programado ese día (si no, el probe no estaría
	# probando nada).
	var fx_on_close: Dictionary = WorldTickEngine.user_fixture_on(w, club_id)
	print("fixture real del día de cierre (%d): %s" % [w, fx_on_close])
	if fx_on_close.is_empty() or String(fx_on_close.get("competition", "")) != "friendly":
		print("(sin amistoso justo en el día de cierre en esta semilla — el sub-check de colisión no aplica, se sigue igual)")

	var ev_start: Dictionary = cal._event_for_day(0)
	var ev_close: Dictionary = cal._event_for_day(w)
	var ev_mid: Dictionary = cal._event_for_day(int(w / 2))
	print("inicio (día 0): %s" % ev_start)
	print("cierre (día %d): %s" % [w, ev_close])
	print("medio de la ventana (día %d): %s" % [int(w / 2), "vacío" if ev_mid.is_empty() else ev_mid])
	if ev_start.is_empty() or String(ev_start.get("label", "")).find("Arranca") < 0:
		print("FALLA: el día de inicio debería mostrar 'Arranca...'")
		ok = false
	if ev_close.is_empty() or String(ev_close.get("label", "")).find("Cierra") < 0:
		print("FALLA: el día de cierre debería mostrar 'Cierra...' (el bug real: se lo comía el amistoso)")
		ok = false
	if not ev_mid.is_empty():
		print("FALLA: un día del medio de la ventana ya no debería marcarse")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
