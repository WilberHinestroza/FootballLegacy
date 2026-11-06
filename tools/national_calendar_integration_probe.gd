extends Node

## Prueba dirigida de la integración de partidos de SELECCIÓN al mismo
## camino que los de club (Parte 91, pedido explícito de Wilber: "deben
## ser como los demás, salir en el calendario y jugarse como se juegan
## los demás, nada distinto"). Antes: WorldTickEngine._tick_fixtures()
## nunca emitía user_match_today para un fixture de selección (el Hub
## jamás se enteraba solo), y WorldTickEngine.advance_until_live()
## (usado por "Simular hasta esta fecha" del Calendario) tampoco frenaba
## para uno — un partido de selección podía quedar resuelto por la IA de
## fondo sin que el usuario lo jugara ni lo supiera.
##
## Arma un mundo real, resuelve una eliminatoria real (QualifyingEngine,
## mismo camino que _tick_international_window), escanea días hasta
## encontrar uno con un partido REAL de selección para el usuario (no
## se inventa un fixture a mano), y confirma:
##   1. WorldTickEngine.pending_user_national_fixture() no está vacío ESE día.
##   2. advance_until_live() hacia un objetivo MÁS ALLÁ de ese día se
##      DETIENE justo ahí con "match_pending" (antes seguía de largo).
##   3. Hub._today_unplayed_fixture()/_fixture_line()/_launch_fixture()
##      reconocen el fixture de selección y arman el partido con el
##      launcher correcto (NationalTeamMatchLauncher), sin crashear.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/NationalCalendarIntegrationProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	var p := PlayerData.new()
	p.player_name = "Probe Calendario"
	p.country = "Argentina"
	p.club_id = ""   # sin club real en este mundo de prueba — no debe hacer falta para lo que probamos
	p.position = "ST"
	p.overall = 100 # convocatoria absoluta segura para que el tick no altere el caso de prueba
	SaveManager.save_world_seed(world_seed)
	SaveManager.save_player(p)

	# Convocado (mismo criterio que _tick_international_window: guardado en
	# "international", no en player) — sin esto pending_user_national_fixture
	# corta en seco por diseño (nunca ofrece partido a quien no está convocado).
	var intl: Dictionary = SaveManager.load_international()
	intl["cycle_start_epoch_day"] = 0
	intl["user_callup_status"] = {"window_start_day": 0, "called_up": true, "status": "regular", "probability": 0.3}
	SaveManager.save_international(intl)

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"season_start_epoch_day": 0, "league_id": -1}
	WorldTickEngine.user_club_id = ""
	WorldTickEngine.current_epoch_day = 15
	# Fijar el ciclo real antes de marcar la convocatoria; de lo contrario,
	# el primer tick de la sonda inicializa el ciclo y limpia ese estado.
	var intl_runtime: Dictionary = SaveManager.load_international()
	intl_runtime["cycle_start_epoch_day"] = WorldTickEngine._international_cycle_start()
	intl_runtime["user_callup_status"] = {"window_start_day": 0, "called_up": true, "status": "regular", "probability": 0.3}
	SaveManager.save_international(intl_runtime)

	# Escanea hasta encontrar un día real con partido de selección para el
	# usuario (QualifyingEngine real, no inventado).
	# Arranca en 15 (no 0): advance_until_live() AVANZA primero y recién
	# después chequea, así que si el día de partido fuera el día 0 y
	# arrancáramos ahí mismo, lo saltaría de largo sin poder frenar en
	# él — un artefacto de arrancar justo EN el día del partido, no algo
	# que pase en el juego real (siempre se llama desde un día anterior).
	var found_day: int = -1
	var fx: Dictionary = {}
	for day in range(15, 400):
		WorldTickEngine.current_epoch_day = day
		var candidate: Dictionary = WorldTickEngine.pending_user_national_fixture()
		if not candidate.is_empty():
			found_day = day
			fx = candidate
			break

	if found_day < 0:
		print("PROBE FAIL (no se encontró ningún día con partido de selección real en 400 días — ¿cambió QualifyingEngine?)")
		get_tree().quit(1)
		return
	print("día %d: partido de selección real encontrado -> vs %s (competition=%s, is_home=%s)" % [
		found_day, fx.get("opponent", "?"), fx.get("competition", "?"), fx.get("is_home", "?")])

	var ok: bool = true

	# La fecha FIFA debe seguir visible para el país aunque el usuario no esté
	# convocado; en ese caso no bloquea el avance ni abre un partido jugable.
	var intl_not_called: Dictionary = SaveManager.load_international()
	var status_not_called: Dictionary = intl_not_called.get("user_callup_status", {})
	status_not_called["called_up"] = false
	status_not_called["status"] = "left_out"
	intl_not_called["user_callup_status"] = status_not_called
	SaveManager.save_international(intl_not_called)
	WorldTickEngine.current_epoch_day = found_day
	var scheduled_not_called: Dictionary = WorldTickEngine.user_national_fixture_on(found_day)
	var still_playable: Dictionary = WorldTickEngine.pending_user_national_fixture()
	print("sin convocatoria: fixture visible=%s · partido jugable pendiente=%s" % [
		not scheduled_not_called.is_empty(), not still_playable.is_empty()])
	if scheduled_not_called.is_empty() or bool(scheduled_not_called.get("called_up", true)) or not still_playable.is_empty():
		print("FALLA 0: el partido FIFA sin convocatoria no aparece o quedó jugable")
		ok = false
	else:
		if String(scheduled_not_called.get("opponent", "")) != String(fx.get("opponent", "")):
			print("FALLA 0b: el fixture programado cambió de rival")
			ok = false
	var calendar_script: GDScript = load("res://scenes/Calendar/Calendar.gd")
	var calendar = calendar_script.new()
	calendar._club_id = ""
	calendar._nat_country = p.country
	calendar._today_epoch_day = found_day
	calendar._nat_qualifying = WorldTickEngine.national_qualifying_for(Confederations.confederation_of(p.country))
	calendar._nat_wc = WorldTickEngine.world_cup_this_cycle()
	calendar._nat_ncup = WorldTickEngine.national_cup_for(Confederations.confederation_of(p.country))
	var no_call_event: Dictionary = calendar._event_for_day(found_day)
	print("calendario sin convocatoria: %s (%s)" % [no_call_event.get("label", ""), no_call_event.get("callup_state", "")])
	if String(no_call_event.get("callup_state", "")) != "not_called" or (no_call_event.get("fixture", {}) as Dictionary).is_empty():
		print("FALLA 0c: el calendario no muestra el partido si no hay convocatoria")
		ok = false
	calendar.free()
	# Restaurar el estado convocado para probar el flujo jugable que ya existe.
	var intl_restore: Dictionary = SaveManager.load_international()
	var restore_status: Dictionary = intl_restore.get("user_callup_status", {})
	restore_status["called_up"] = true
	restore_status["status"] = "regular"
	restore_status["probability"] = 1.0
	intl_restore["user_callup_status"] = restore_status
	SaveManager.save_international(intl_restore)
	var calendar_called = calendar_script.new()
	calendar_called._club_id = ""
	calendar_called._nat_country = p.country
	calendar_called._today_epoch_day = found_day
	calendar_called._nat_qualifying = WorldTickEngine.national_qualifying_for(Confederations.confederation_of(p.country))
	calendar_called._nat_wc = WorldTickEngine.world_cup_this_cycle()
	calendar_called._nat_ncup = WorldTickEngine.national_cup_for(Confederations.confederation_of(p.country))
	var called_event: Dictionary = calendar_called._event_for_day(found_day)
	print("calendario convocado: %s (%s)" % [called_event.get("label", ""), called_event.get("callup_state", "")])
	if String(called_event.get("callup_state", "")) != "called" or (called_event.get("fixture", {}) as Dictionary).is_empty():
		print("FALLA 0d: el calendario no habilita el partido cuando sí hay convocatoria")
		ok = false
	calendar_called.free()

	# --- 1) advance_until_live() debe FRENAR en cuanto el partido de
	# selección queda pendiente (no necesariamente en `found_day` exacto:
	# igual que un fixture de club, uno de Mundial/copa queda "pendiente"
	# desde su día real hasta que se juega, así que puede frenar antes si
	# el escaneo de arriba encontró el fixture ya en curso) ---
	WorldTickEngine.current_epoch_day = 0
	var reason: String = await WorldTickEngine.advance_until_live(found_day + 20)
	var still_pending: bool = not WorldTickEngine.pending_user_national_fixture().is_empty()
	print("advance_until_live() paró en día %d con reason=%s (¿sigue pendiente ahí?=%s)" % [WorldTickEngine.current_epoch_day, reason, still_pending])
	if reason != "match_pending" or not still_pending or WorldTickEngine.current_epoch_day > found_day:
		print("FALLA 1: no frenó por un partido de selección real y pendiente, o frenó DESPUÉS del día encontrado")
		ok = false

	# --- 2) Hub: _today_unplayed_fixture / _fixture_line / _launch_fixture ---
	var hub_script: GDScript = load("res://scenes/Hub/Hub.gd")
	var hub = hub_script.new()
	hub._player = p
	hub._world = world
	var today_fx: Dictionary = hub._today_unplayed_fixture()
	print("Hub._today_unplayed_fixture(): vacío=%s opponent=%s" % [today_fx.is_empty(), today_fx.get("opponent", "?")])
	if today_fx.is_empty() or not today_fx.has("opponent"):
		print("FALLA 2: Hub no reconoce el partido de selección de hoy")
		ok = false
	else:
		var line: String = hub._fixture_line(today_fx)
		print("Hub._fixture_line(): %s" % line)
		if not line.contains(String(today_fx.get("opponent", "###"))):
			print("FALLA 3: la línea del fixture no menciona al rival real")
			ok = false

		# No se corre _launch_fixture() de punta a punta acá (correría un
		# partido real + cambiaría de escena, demasiado para esta prueba) —
		# se llama al MISMO launcher con los MISMOS argumentos que arma
		# _launch_fixture() para un fixture de selección, para confirmar
		# que el armado de MatchState queda bien sin instanciar Hub.tscn.
		var season_start: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
		var prep: Dictionary = NationalTeamMatchLauncher.prepare(
			world, world_seed, season_start, p, p.country, String(today_fx.get("opponent", "")),
			bool(today_fx.get("is_home", true)), float(today_fx.get("user_start_chance", 0.0)),
			"res://scenes/Hub/Hub.tscn", true,
			String(today_fx.get("competition", "qualifying")), bool(today_fx.get("is_knockout", false)), String(today_fx.get("key", "")))
		var launched_ok: bool = bool(prep.get("ok", false)) and MatchState.fixture.has("home_country") and MatchState.fixture.has("away_country")
		print("NationalTeamMatchLauncher.prepare() con los args de _launch_fixture(): ok=%s fixture=%s" % [launched_ok, MatchState.fixture])
		if not launched_ok:
			print("FALLA 4: el armado de MatchState para un fixture de selección no quedó bien")
			ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
