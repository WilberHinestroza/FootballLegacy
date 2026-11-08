extends Node
## Autoload. Fuente ÚNICA de avance de día — equivalente directo a
## DailyTickEngine en Football Legacy.
##
## Aprendizaje crítico de FL: Hub, Training y Match NUNCA duplican lógica
## de avance de tiempo. Todas las pantallas llaman a advance_day() de aquí.
##
## Desde Fase 4 cachea la temporada activa (`season`) y el mundo completo.
## En cada avance comprueba si hoy juega el usuario (`user_match_today`).
##
## Mundo VIVO (Fase 5): las tablas de las 55 ligas se calculan al vuelo
## (SeasonEngine + LeagueTable), sin persistir resultados de IA — son
## función pura de (world_seed, fixture). El save solo guarda el día
## actual, el cuadro de copa del usuario y sus resultados reales.

signal day_advanced(new_epoch_day: int)
signal user_match_today(fixture: Dictionary)
signal season_ended # ver last_season_report — la ceremonia de fin de temporada se engancha acá
signal sim_tick(current_epoch_day: int, target_epoch_day: int) # progreso de advance_until_live (Calendario)

## Resumen de la temporada que acaba de terminar (jugador + club + Balón
## de Oro del mundo) — armado una sola vez en _finish_season_rollover(),
## se lee y se descarta (nunca se persiste). Ver SeasonReportEngine.gd.
var last_season_report: Dictionary = {}

## true justo cuando arranca la secuencia de fin de temporada (pedido
## explícito: "resumen → premios individuales → carga de la nueva
## temporada", tres pantallas en ese orden, no directo al Hub). Transient,
## como last_season_report — nunca se persiste. Lo consume SeasonCeremony
## (decide a dónde va "Continuar") y Awards (decide si su botón dice
## "Continuar" hacia la carga, en vez de "Volver" al Hub). Se apaga en
## SeasonLoading, al final de la cadena.
var post_season_flow: bool = false

const SEASON_START_EPOCH_DAY := 0

## Puntos de energía física (PlayerData.fatigue_physical) que se recuperan
## por día de descanso. Los eventos de la sección Mensajes la consumen.
const FATIGUE_DAILY_RECOVERY := 6.0
const FATIGUE_MENTAL_DAILY_RECOVERY := 4.0

var current_epoch_day: int = SEASON_START_EPOCH_DAY
var season: Dictionary = {}
## Titular que la pantalla de Noticias debe abrir/resaltar al entrar
## (lo setea el Hub al tocar una tarjeta de prensa). "" = ninguno.
var focus_news_key: String = ""
var user_club_id: String = ""
var world_seed: int = 0
var world: Dictionary = {}                 # WorldFactory.build() cacheado
var cup: Dictionary = {}                   # cuadro de copa del usuario, RESUELTO (vista, no se persiste)

var _strength_by_club: Dictionary = {}     # club_id -> fuerza (int), TODAS las ligas

## Cachés de "mundo vivo" por día. ballon_dor_ranking() recorre las 55
## ligas y para cada una pide tabla + goleadores, y AMBAS reconstruían
## fixtures y simulaban disciplina por separado — el doble de trabajo por
## liga. Se memoiza por día (se limpia solo al cambiar current_epoch_day).
var _fixtures_cache: Dictionary = {}       # league_id -> Array de fixtures (no cambian en la temporada)
var _fixtures_cache_start: int = -1        # season_start_epoch_day con el que se llenó
var _disc_cache: Dictionary = {}           # league_id -> dict de DisciplineEngine.simulate_league
var _disc_cache_day: int = -1

## Carga la temporada del slot activo y sincroniza el contador de día.
## Idempotente: llamar al entrar a la carrera (Continuar / elegir club /
## Hub._ready) sin miedo a duplicar estado.
func load_runtime() -> void:
	season = SaveManager.load_season()
	current_epoch_day = int(season.get("current_epoch_day", SEASON_START_EPOCH_DAY))
	world_seed = SaveManager.load_world_seed()
	# Sal por carrera del mercado de fichajes (SaveManager v24): con el mundo
	# importado el world_seed es fijo para todas las carreras, así que sin
	# esto SIEMPRE salían los mismos fichajes. 0 en saves viejos = sin efecto.
	TransferMarketEngine.set_salt(SaveManager.load_market_salt())
	TransferMarketEngine.set_v2_from(SaveManager.load_market_v2_from())
	var p := SaveManager.load_player()
	user_club_id = p.club_id if p != null else ""
	Avatar.user_kit_hex = ""
	Avatar.user_kit2_hex = ""
	Avatar.user_kit_w = -1

	world = {}
	_strength_by_club = {}
	cup = {}
	_fixtures_cache.clear()
	_fixtures_cache_start = -1
	_disc_cache.clear()
	_disc_cache_day = -1
	_ballon_dor_cache = []
	_ballon_dor_cache_day = -1
	_user_cont_cache = {}
	_user_cont_cache_day = -1
	_user_cont_cache_res = -1
	# Bug real de la auditoría (ronda 6): a diferencia de los demás caches
	# de esta función, _coef_cache nunca se limpiaba acá — si el usuario
	# cambia de carrera/slot en la misma sesión y el epoch_day nuevo
	# coincide con el día cacheado de la carrera VIEJA, coefficient_ranking()
	# devolvía el ranking del mundo anterior.
	_coef_cache = {}
	_coef_cache_day = -1
	Crest._league_slot.clear() # el reparto de escudos depende del mundo de ESTA carrera
	if not season.is_empty():
		world = WorldFactory.build(world_seed)
		# Ascensos y descensos (ver PromotionRelegationEngine.gd): world es
		# funcion pura de world_seed, nunca se persiste, asi que el historial
		# acumulado de movimientos entre categorias se reaplica ACA, siempre,
		# antes de que nada mas lea clubs_by_league/club_meta_by_id.
		WorldFactory.apply_league_overrides(world, SaveManager.load_league_tiers())
		var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
		var season_start: int = int(season.get("season_start_epoch_day", 0))
		# base_overall del metadato es un buen proxy de fuerza sin
		# materializar plantillas. Cubre las 55 ligas. Se le suma el efecto
		# NETO de los fichajes REALES de esta temporada (a quién se fichó
		# de verdad, no un roll al azar desconectado — ver
		# TransferMarketEngine.generate_season_transfers/net_strength_deltas).
		var transfers: Array = TransferMarketEngine.season_transfers_cached(world, world_seed, season_start)
		var deltas: Dictionary = TransferMarketEngine.net_strength_deltas(transfers)
		for club_id in meta_by_id:
			var base: int = int(meta_by_id[club_id].get("base_overall", 55))
			var delta: int = int(deltas.get(club_id, 0))
			_strength_by_club[club_id] = clampi(base + delta, 30, 99)
		_reinject_replacement_coach()
		# Auto-corrección (Wilber, Parte 93b): partidas donde un fichaje a
		# mitad de temporada YA quedó con season["league_id"] apuntando al
		# club viejo (el bug de fondo — _tick_pending_transfer no
		# reconstruía liga/copa — ya está corregido ahí para fichajes
		# NUEVOS, pero eso no repara un save que quedó en ese estado antes
		# del fix). _rebuild_season_for_new_club ya es un no-op si
		# league_id ya coincide, así que esto es barato en cada carga.
		var league_id_before: int = int(season.get("league_id", -1))
		_rebuild_season_for_new_club(user_club_id)
		if int(season.get("league_id", -1)) != league_id_before:
			SaveManager.save_season(season)
		_refresh_cup()
		_sync_user_kit_tint()

## El avatar del usuario (Avatar.for_player) viste el kit de su club:
## camiseta = color primario (Avatar.user_kit_hex), short = secundario
## (Avatar.user_kit2_hex). Sin club o sin color → "" (queda el tinte que
## haya elegido/determinista).
func _sync_user_kit_tint() -> void:
	var hex: String = ""
	var hex2: String = ""
	if user_club_id != "":
		var club: ClubData = WorldFactory.find_club(world, user_club_id)
		if club != null:
			hex = club.primary_color_hex
			hex2 = club.secondary_color_hex
	Avatar.user_kit_hex = hex
	Avatar.user_kit2_hex = hex2
	# Diseño de camiseta de la temporada (plantilla de Wilber) para que tu
	# jugador vista las rayas/cuadros del kit, no un color liso.
	Avatar.user_kit_w = -1
	Avatar.user_kit_sec_hex = ""
	Avatar.user_kit_club = user_club_id
	if user_club_id != "":
		var kclub: ClubData = WorldFactory.find_club(world, user_club_id)
		if kclub != null:
			Avatar.user_kit_w = int(Kit.for_club_kit(kclub, get_season_start_year(), false).get("w", -1))
			Avatar.user_kit_sec_hex = (Kit._club_colors(kclub)[1] as Color).to_html(false)
			Avatar.user_kit_hex = (Kit._club_colors(kclub)[0] as Color).to_html(false)

## Si esta temporada destituyeron al DT del club del usuario
## (CoachChangeEngine), el reemplazo vive en season["coach_replacement"] y
## hay que volver a inyectarlo en el `world` recién reconstruido.
func _reinject_replacement_coach() -> void:
	var repl = season.get("coach_replacement", null)
	if repl is Dictionary and not repl.is_empty() and user_club_id != "":
		var coaches: Dictionary = world.get("coach_by_club_id", {})
		coaches[user_club_id] = CoachChangeEngine.coach_from_dict(user_club_id, repl)
		world["coach_by_club_id"] = coaches

## Recalcula el cuadro de copa resuelto (barato: ~5 rondas x ~8 partidos).
## two_legged_until_final=true: el cruce del USUARIO sigue viniendo del
## override en season["results"] (ya resuelto a ida y vuelta de verdad por
## _next_user_cup_fixture/_record_cup_leg) — esto solo cambia cómo se
## resuelven de fondo los OTROS cruces del mismo cuadro (bug real de la
## auditoría: antes siempre a partido único).
func _refresh_cup() -> void:
	cup = {}
	if not season.is_empty():
		cup = SeasonEngine.resolve_cup(
			season.get("cup", {}), world_seed, _strength_by_club,
			season.get("results", {}), current_epoch_day, true,
		)

func has_active_season() -> bool:
	return not season.is_empty()

## Qué hizo el jugador ESTE día. "rest" (por defecto) = descansó y recupera
## energía física; "train" = entrenó, no gasta energía pero tampoco la
## recupera (pedido de Wilber: la estamina solo baja jugando; entrenar la
## deja igual, descansar la sube). Lo setea quien llama a advance_day().
var last_day_activity: String = "rest"

## Recuperación de energía física por día de DESCANSO — un solo lugar, lo
## usan el tick y la tarjeta del Hub para mostrar el ritmo.
func daily_energy_recovery(player: PlayerData) -> float:
	if player == null:
		return FATIGUE_DAILY_RECOVERY
	return FATIGUE_DAILY_RECOVERY + StaffEngine.energy_recovery_bonus(player)

func advance_day(day_activity: String = "rest") -> void:
	last_day_activity = day_activity
	current_epoch_day += 1
	if not season.is_empty():
		season["current_epoch_day"] = current_epoch_day
		_refresh_cup()   # el día que pasa puede dejar decididas más rondas

	_tick_finances()
	_tick_investments()
	_tick_fixtures()
	_tick_press()
	_tick_transfer_window_news()
	_tick_deadline_day()
	_tick_precontract()
	_tick_international_window()
	_tick_national_trophies()
	_tick_life_events()
	_tick_offer_deadlines()
	_tick_pending_transfer()
	_tick_fatigue_and_development()
	_tick_coach_change()
	_tick_sentiment()

## Humor de la afición y clima de vestuario (los mueven la zona mixta y los
## resultados) DECAEN solos hacia el neutro; la narrativa de prensa que deja
## una entrevista caduca a los ~12 días. Estado no-schema en `season`.
func _tick_sentiment() -> void:
	if season.is_empty():
		return
	var changed := false
	if season.has("fan_sentiment"):
		var fs: int = int(season["fan_sentiment"])
		if fs != InterviewEngine.FAN_DEFAULT and current_epoch_day % 2 == 0:
			season["fan_sentiment"] = fs + (1 if fs < InterviewEngine.FAN_DEFAULT else -1)
			changed = true
	if season.has("dressing_room"):
		var dr: int = int(season["dressing_room"])
		if dr != InterviewEngine.DRESSING_DEFAULT and current_epoch_day % 3 == 0:
			season["dressing_room"] = dr + (1 if dr < InterviewEngine.DRESSING_DEFAULT else -1)
			changed = true
	if season.has("press_narrative") and String(season["press_narrative"]) != "":
		var since: int = int(season.get("press_narrative_day", current_epoch_day))
		if not season.has("press_narrative_day"):
			season["press_narrative_day"] = current_epoch_day
			changed = true
		elif current_epoch_day - since >= 12:
			season["press_narrative"] = ""
			season.erase("press_narrative_day")
			changed = true
	if changed:
		SaveManager.save_season(season)

	# No relanzar el rollover si ya hay una decisión de contrato pendiente
	# (si no, se regenerarían las ofertas cada día hasta que el usuario elija).
	# SIEMPRE a los SeasonCalendar.season_length_days() exactos desde que
	# arrancó ESTA temporada (365, o 365+WC_YEAR_EXTRA_DAYS en año de
	# Mundial — Parte 91n) — no "cuando termine la liga": la final de la
	# copa continental (que puede caer más tarde que la liga, ver
	# ContinentalEngine.CONTINENTAL_FINAL_TARGET_DAY) y, en año de Mundial,
	# la final del Mundial mismo (que ahora arranca a mediados de junio,
	# después de terminado el campeonato de club) tienen que verse
	# resueltas ANTES del rollover.
	if not season.is_empty() and not season.get("awaiting_contract_decision", false) \
			and current_epoch_day > int(season.get("season_start_epoch_day", 0)) + SeasonCalendar.season_length_days(get_season_start_year()):
		_begin_season_rollover() # calendario agotado: consume un año de contrato

	if not season.is_empty():
		SaveManager.save_season(season)  # solo día + copa + overrides del usuario; los resultados de IA no se guardan

	day_advanced.emit(current_epoch_day)

## Avanza el mundo día a día hasta `target_epoch_day` (inclusive) — fuente
## ÚNICA para "simular hasta una fecha" (pedido explícito desde el
## Calendario, mismo criterio que ya usaban los botones Semana/Mes/
## Siguiente partido del Hub: CUALQUIER pantalla que necesite avanzar
## varios días de golpe llama ACÁ, nunca repite su propio bucle de
## advance_day(), ver regla de "fuente única de avance de tiempo" en
## CLAUDE.md). Se PARA antes de llegar si aparece algo que el jugador
## necesita ver/decidir — nunca se salta un partido propio, una decisión
## de contrato o un cierre de temporada sin avisar. Devuelve por qué se
## detuvo, para que quien llamó decida a qué pantalla ir:
##   "reached_target" | "match_pending" | "contract_decision" | "season_ended"
func advance_until(target_epoch_day: int) -> String:
	while current_epoch_day < target_epoch_day:
		advance_day()
		if season.get("awaiting_contract_decision", false):
			return "contract_decision"
		if not last_season_report.is_empty():
			return "season_ended"
		var fx: Dictionary = pending_user_fixture()
		if not fx.is_empty():
			return "match_pending"
		# Mismo fix que ya tiene advance_until_live() (Parte 91) — bug real
		# encontrado en la auditoría: a ESTE gemelo síncrono nunca se le
		# había replicado, así que seguía pudiendo saltarse un partido de
		# selección sin avisar, resuelto por la IA de fondo sin acreditar
		# caps/goles/asistencias reales.
		if not pending_user_national_fixture().is_empty():
			return "match_pending"
	return "reached_target"

## Igual que advance_until, pero ASÍNCRONO y con progreso: cede un frame
## entre días y emite `sim_tick` por cada día avanzado, para que el
## Calendario muestre el avance en vivo (pedido de Wilber: "que desde el
## calendario te vaya mostrando cómo avanza y el resultado de cada
## partido"). Sigue delegando en advance_day() — fuente única de avance de
## tiempo, no reinventa el tick — y devuelve los MISMOS motivos de parada
## que advance_until: "reached_target" | "match_pending" |
## "contract_decision" | "season_ended".
func advance_until_live(target_epoch_day: int) -> String:
	while current_epoch_day < target_epoch_day:
		advance_day()
		sim_tick.emit(current_epoch_day, target_epoch_day)
		if season.get("awaiting_contract_decision", false):
			return "contract_decision"
		if not last_season_report.is_empty():
			return "season_ended"
		if not pending_user_fixture().is_empty():
			return "match_pending"
		# Partido de SELECCIÓN (Parte 91, "nada distinto"): antes esto NUNCA
		# frenaba el avance masivo del Calendario — "Simular hasta esta
		# fecha" podía pasar por encima de un partido de selección sin
		# ofrecerte jugarlo/simularlo de verdad, dejándolo resuelto por la
		# IA de fondo sin acreditarte caps/goles/asistencias reales.
		if not pending_user_national_fixture().is_empty():
			return "match_pending"
		await Engine.get_main_loop().process_frame
	return "reached_target"

## Al agotarse el calendario de liga+copa: el contrato consume un año.
## Si sigue teniendo contrato, la temporada siguiente arranca sola en el
## mismo club (sin fricción). Si el contrato se agota, se PARA aquí: se
## genera la oferta de renovación del club + fichajes externos (Fase 8b,
## mercado de fichajes) y se espera la decisión del usuario — ver
## resolve_contract_decision() y scenes/ContractDecision/.
func _begin_season_rollover() -> void:
	var player := SaveManager.load_player()
	if player == null:
		return

	# Vuelta de cesión (LoanEngine): terminó la temporada del préstamo, el
	# jugador regresa al club padre con SU contrato. Se hace ANTES de
	# decrementar el año y de decidir renovación/ofertas, para que todo eso
	# corra sobre el club padre, no sobre el de la cesión.
	var lr = season.get("loan_return", null)
	if lr is Dictionary and not (lr as Dictionary).is_empty():
		player.club_id = String(lr["parent_club_id"])
		player.wage = int(lr.get("parent_wage", player.wage))
		player.contract_years_remaining = int(lr.get("parent_contract_years", player.contract_years_remaining))
		player.club_seniority = 0
		player.coach_trust = 50
		season.erase("loan_return")
		PressGenerator.append_to_feed(player, {
			"headline": "Vuelve de su cesión",
			"body": "Termina el préstamo y %s se reincorpora a %s." % [player.player_name, String(lr.get("parent_club_name", "su club"))],
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)

	player.contract_years_remaining = maxi(player.contract_years_remaining - 1, 0)

	# --- El jugador CUMPLE UN AÑO cada temporada (antes NUNCA envejecía →
	#     retiro/capitanía/enfriamiento de mercado eran inalcanzables). ---
	player.age += 1
	if player.birth_epoch_day != 0:
		player.birth_epoch_day -= 365  # mantener coherente si algo lo deriva

	# --- Reputación: sube/baja hacia un objetivo derivado de tu nivel +
	#     palmarés + la nota media de la temporada que termina. Gradual
	#     (máx +6 / -3 por año) para que un crack tarde ~4-5 temporadas en
	#     llegar a la élite. Antes SOLO la movían entrevistas/redes/vida. ---
	var rep_target: int = clampi(player.overall - 4 + player.trophies_won * 3 + int(player.career_goals / 40.0) + int(player.career_assists / 55.0), 25, 99)
	var games: int = int(season.get("user_rating_games", 0))
	if games > 0:
		var avg: float = float(season.get("user_rating_sum", 0.0)) / float(games)
		if avg >= 7.6:
			rep_target += 6
		elif avg >= 7.0:
			rep_target += 2
		elif avg < 6.0:
			rep_target -= 4
	# El paso hacia el objetivo escala con la brecha: un crack que acaba de
	# reventar la liga no tarda 6 años en que lo reconozcan.
	var gap: int = rep_target - player.reputation
	var step: int = clampi(gap, -4, 6)
	if gap > 16:
		step = clampi(gap, -4, 12)
	player.reputation = clampi(player.reputation + step, 0, 100)

	# --- Valor de mercado: se recalcula con la media/potencial/edad ACTUALES
	#     (antes solo cambiaba al fichar → se congelaba si renovabas). ---
	player.market_value = TransferMarketEngine.market_value(player.overall, player.potential, player.age)

	SaveManager.save_player(player)

	# Precontrato firmado (PreContractEngine): se acaba tu contrato y te vas
	# libre al club con el que pactaste, sin pantalla de renovación.
	var pc: Dictionary = PreContractEngine.take_on_expiry(player, season)
	if not pc.is_empty():
		SaveManager.save_player(player)
		var pc_club: String = String(pc.get("from_club_id", ""))
		resolve_contract_decision(pc_club, int(pc.get("wage", player.wage)), int(pc.get("contract_years", 3)))
		pending_presentation = {"club_id": pc_club, "years": int(pc.get("contract_years", 3)), "loan": false}
		var np := SaveManager.load_player()
		if np != null:
			PressGenerator.append_to_feed(np, {
				"headline": "%s llega libre a %s" % [Nickname.press_name(np, world_seed), String(pc.get("from_club_name", "su nuevo club"))],
				"body": "Se cumple el precontrato: termina su contrato y firma por %d temporadas, con una prima de fichaje de %s." % [int(pc.get("contract_years", 3)), CurrencyFormat.format(int(pc.get("signing_bonus", 0)))],
				"source": "MERCADO", "sentiment": "POSITIVE",
			}, current_epoch_day)
			SaveManager.save_player(np)
		return

	if player.contract_years_remaining > 0:
		_finish_season_rollover(player.club_id)
		return

	var pos_ratio: float = _league_position_ratio(player.club_id)
	var agent_mult: float = AgentEngine.wage_multiplier(player.agent_stars)
	# Mismo bug de la auditoría que en WageOfferEngine.generate_offer(): el
	# multiplicador del agente se aplicaba DESPUÉS del techo de
	# renewal_wage(), pudiendo esquivarlo.
	var renewal_wage: int = mini(int(round(ContractEngine.renewal_wage(player.wage, player.coach_trust, pos_ratio, player.overall) * agent_mult)), ContractEngine.wage_ceiling(player.overall))
	var pseudo_rating: float = CareerSetup.pseudo_rating_from_trust(player.coach_trust)
	# Un jugador CONSAGRADO atrae a clubes grandes aunque su relación con el
	# DT actual sea tibia (antes las ofertas al vencer contrato dependían
	# SOLO de coach_trust → un Balón de Oro con DT nuevo recibía ofertas de
	# "promesa"). Mezclamos su nivel real + reputación + palmarés.
	var standing: float = clampf(
		(float(player.overall) - 60.0) / 6.0
		+ float(player.reputation) / 25.0
		+ float(player.trophies_won) * 0.4, 0.0, 6.0)
	pseudo_rating = clampf(maxf(pseudo_rating, 3.0 + standing), 1.0, 10.0)
	var external: Array = CareerSetup.generate_offers(player, pseudo_rating, world)
	external = external.filter(func(o): return o["club_id"] != player.club_id)
	for o in external:
		# Mismo bug de techo esquivado que ya se corrigió arriba en
		# renewal_wage (auditoría, ronda 2) — acá quedaba sin re-clampear.
		o["wage"] = mini(int(round(int(o["wage"]) * agent_mult)), ContractEngine.wage_ceiling(player.overall)) # el agente negocia igual con clubes externos

	# Retiro por edad: a partir de los 34 el mercado se enfría; a los 38
	# ya no llega nadie y no hay renovación → en ContractDecision solo
	# queda "colgar los botines" (que lleva al Salón de la Fama).
	var renewal_offer: Dictionary = {"club_id": player.club_id, "wage": renewal_wage}
	if player.age >= 38:
		external = []
		renewal_offer = {}
		season["forced_retirement"] = true
	elif player.age >= 34:
		var keep: int = 2 if player.age <= 35 else 1
		external = external.slice(0, keep)
		renewal_offer["wage"] = int(round(renewal_wage * (0.85 if player.age <= 35 else 0.7)))

	season["awaiting_contract_decision"] = true
	season["renewal_offer"] = renewal_offer
	season["transfer_offers"] = external.slice(0, 3)

func _league_position_ratio(club_id: String) -> float:
	var table := user_league_table()
	if table.is_empty():
		return 0.5
	var row: Dictionary = LeagueTable.row_for(table, club_id)
	if row.is_empty():
		return 0.5
	return float(int(row["pos"]) - 1) / float(maxi(table.size() - 1, 1))

## Igual que el privado pero para el club del usuario — lo usa la pantalla
## "Mi agente" (AgentEngine.request_raise).
func user_league_position_ratio() -> float:
	return _league_position_ratio(user_club_id)

## Llamado desde ContractDecision al elegir (renovar o fichar por otro
## club). club_id/wage ya vienen de la oferta elegida (renewal_offer o uno
## de transfer_offers).
## `years` > 0 = duración negociada (ver ContractNegotiation); 0 = la de
## siempre. `extras` = {goal_bonus, release_clause} — no hay campo de
## esquema para eso, se guarda en `season` como sabor (se pierde al
## terminar ese contrato, no pasa nada).
func resolve_contract_decision(club_id: String, wage: int, years: int = 0, extras: Dictionary = {}) -> void:
	var player := SaveManager.load_player()
	if player == null:
		return
	var is_transfer: bool = club_id != player.club_id
	if is_transfer:
		ImmersionEngine.note_club_left(player, world, club_id, get_season_start_year())   # v34
	player.club_id = club_id
	player.wage = wage
	if years > 0:
		player.contract_years_remaining = years
	else:
		player.contract_years_remaining = ContractEngine.STARTING_CONTRACT_YEARS if is_transfer else ContractEngine.RENEWAL_YEARS
	if is_transfer:
		player.coach_trust = CoachRelations.TRUST_BASELINE # entrenador nuevo, relación desde cero
		ImageRightsEngine.on_new_club(player) # los derechos de imagen se pactan de nuevo
	SaveManager.save_player(player)

	season.erase("awaiting_contract_decision")
	season.erase("renewal_offer")
	season.erase("transfer_offers")
	_finish_season_rollover(club_id)

	if not extras.is_empty():
		# _finish_season_rollover reconstruye `season` → esto va DESPUÉS.
		season["contract_extras"] = {
			"goal_bonus": int(extras.get("goal_bonus", 0)),
			"release_clause": int(extras.get("release_clause", 0)),
		}
		SaveManager.save_season(season)

func _finish_season_rollover(club_id: String) -> void:
	# La capitanía vive en season["is_captain"], y SeasonCalendar.build_season
	# reconstruye `season` entero más abajo — hay que capturar el valor
	# previo ACÁ para saber si la cinta es NUEVA (y no repetir el titular).
	var _prev_captain: bool = bool(season.get("is_captain", false))
	# `league_id` para la temporada NUEVA se resuelve MAS ABAJO, después de
	# aplicar los movimientos de Ascensos/Descensos de esta misma temporada
	# (ver PromotionRelegationEngine.gd) -- si se resolviera acá arriba y el
	# club de `club_id` justo ascendió/descendió, quedaría con la categoría
	# VIEJA.

	var ending_start_year: int = int(season.get("start_year", get_season_start_year()))
	var new_start_year: int = ending_start_year + 1
	# SIEMPRE SeasonCalendar.season_length_days() exactos después del
	# arranque de la temporada que termina — nunca "el último día jugado +
	# un margen": eso es lo que garantiza que cada temporada dure lo mismo
	# y arranque en julio (365 días), salvo que la que termina haya sido
	# año de Mundial (365+WC_YEAR_EXTRA_DAYS, Parte 91n).
	var new_season_start_day: int = int(season.get("season_start_epoch_day", 0)) + SeasonCalendar.season_length_days(ending_start_year)

	# El coeficiente de la temporada que TERMINA (con el ranking que usó
	# para armar sus propios cupos, todavía vigente en `season` acá) decide
	# la posición de cada país para la temporada NUEVA — nunca al revés
	# (ver nota de ContinentalEngine sobre por qué usar el ranking en curso
	# sería circular). "que sea por la posición", pedido explícito.
	var ending_ranking: Dictionary = coefficient_ranking()
	# Persistir el puntaje CRUDO de la temporada que TERMINA (sin la
	# ventana de 2 temporadas — eso lo arma coefficient_ranking() leyendo
	# esto) como el nuevo historial: la próxima vez que se lea, esta
	# temporada pasa a ser "la anterior". Reemplaza entero, nunca se
	# acumula encima (ver nota de v30 en SaveManager.gd).
	var rank_maps_for_history: Dictionary = {}
	for c in Confederations.ALL:
		rank_maps_for_history[c] = _rank_by_league_id(c)
	var raw_scores: Dictionary = CoefficientEngine.raw_scores_by_confederation(
		world, table_for_league, world_seed, _strength_by_club, current_epoch_day,
		int(season.get("season_start_epoch_day", 0)), rank_maps_for_history, _frozen_cont_pool
	)
	SaveManager.save_coefficient_history(raw_scores)
	var next_rankings: Dictionary = {}
	for confederation in Confederations.ALL:
		var rows: Array = ending_ranking.get(confederation, [])
		next_rankings[confederation] = rows.map(func(r): return int(r["league"].league_id))

	# Tabla FINAL de cada liga de primera (las que alimentan copas
	# continentales) — hay que capturarla ACÁ, todavía con `season`/
	# `table_for_league` apuntando a la temporada que TERMINA. Se guarda
	# para que la temporada NUEVA decida sus cupos continentales por esto,
	# nunca por su propia tabla recién arrancada (ver _prev_season_table_for).
	var prev_league_tables: Dictionary = {}
	for lg in world.get("leagues", []):
		if lg.tier != 1:
			continue
		var tbl: Array = table_for_league(lg.league_id)
		prev_league_tables[lg.league_id] = tbl.map(func(r): return String(r["club_id"]))

	# Ascensos y descensos (ver PromotionRelegationEngine.gd) -- calculados
	# ACA, todavia con `world`/`table_for_league` apuntando al roster con el
	# que se jugo la temporada que TERMINA. `league_moves` se usa mas abajo
	# para el efecto financiero y para mutar el mundo.
	var pr_boundaries: Array = PromotionRelegationEngine.tier_boundaries(world)
	var pr_standings: Dictionary = {}
	for b in pr_boundaries:
		pr_standings[int(b["top"].league_id)] = table_for_league(int(b["top"].league_id))
		pr_standings[int(b["bottom"].league_id)] = table_for_league(int(b["bottom"].league_id))
	var league_moves: Array = PromotionRelegationEngine.plan_moves(world, pr_boundaries, pr_standings)

	# Resumen de fin de temporada (jugador + club + Balón de Oro del
	# mundo) — pedido explícito. Se arma ACÁ porque todavía es el último
	# momento en que `season`/`user_club_id` son los de la temporada que
	# TERMINA (current_epoch_day también sigue siendo el de esa
	# temporada) y los contadores del jugador siguen sin resetear (eso
	# pasa recién en _reset_season_stats_and_objective(), más abajo).
	var trophies_gained := 0
	var _supercup_defs: Array = []
	var ending_player := SaveManager.load_player()
	if ending_player != null:
		var ending_table := table_for_league(int(season.get("league_id", -1)))
		var ending_cup := cup_for_league(int(season.get("league_id", -1)))
		var objective_progress := ObjectivesEngine.player_objective_progress(ending_player, season.get("player_objective", {}))
		var ending_club := WorldFactory.find_club(world, user_club_id)
		last_season_report = {
			"start_year": int(season.get("start_year", get_season_start_year())),
			"player_rating": SeasonReportEngine.player_rating(ending_player, ending_table, objective_progress),
			"player_summary": SeasonReportEngine.player_summary_text(ending_player, ending_table),
			"club_summary": SeasonReportEngine.club_summary_text(ending_club, ending_table, ending_cup),
			"club_name": ending_club.club_name if ending_club != null else "",
			"ballon_dor": ballon_dor_ranking().slice(0, 5),
			# Para el resumen tipo "Wrapped" (P5, 10-oct).
			"wrapped": {
				"matches": ending_player.season_matches_played if ending_player != null else 0,
				"goals": ending_player.season_goals if ending_player != null else 0,
				"assists": ending_player.season_key_passes if ending_player != null else 0,
				"avg": float(season.get("user_rating_sum", 0.0)) / float(maxi(int(season.get("user_rating_games", 0)), 1)),
				"level": ending_player.level if ending_player != null else 1,
				"partner": String(ending_player.partner.get("name", "")) if ending_player != null else "",
				"chemistry": SocialLifeEngine.chemistry(ending_player, season) if ending_player != null else 0,
				"position": int(LeagueTable.row_for(ending_table, user_club_id).get("pos", 0)),
			},
		}
		post_season_flow = true
		var ending_row: Dictionary = LeagueTable.row_for(ending_table, user_club_id)
		var won_league: bool = not ending_row.is_empty() and int(ending_row["pos"]) == 1
		var dcup_champ: String = SeasonReportEngine.cup_champion_club_id(ending_cup)
		var won_dcup: bool = dcup_champ == user_club_id
		if won_league:
			trophies_gained += 1
		if won_dcup:
			trophies_gained += 1

		# Supercopa nacional JUGABLE la temporada que viene: campeón de
		# liga vs campeón de copa. Si ganaste las DOS, te la llevás de
		# oficio.
		var lg_champ: String = String(ending_table[0].get("club_id", "")) if not ending_table.is_empty() else ""
		if (won_league or won_dcup) and lg_champ != "" and dcup_champ != "":
			if lg_champ == dcup_champ:
				_supercup_defs.append({"kind": "domestic", "name": "Supercopa nacional", "auto": true})
			else:
				_supercup_defs.append({
					"kind": "domestic", "name": "Supercopa nacional",
					"opp": dcup_champ if won_league else lg_champ})

		# Gabinete de trofeos (schema v20): títulos + honores individuales
		# de la temporada que termina. Se calcula ACÁ, mientras `season` y
		# los rankings siguen siendo los de esa temporada.
		var season_year: int = int(season.get("start_year", get_season_start_year()))
		var honors: Array = HonorsEngine.collect_season(self, ending_player, season_year)
		if HonorsEngine.record(ending_player, honors) > 0:
			SaveManager.save_player(ending_player)
			last_season_report["honors"] = honors

		# Supercopa CONTINENTAL jugable: si ganaste una copa continental,
		# jugás contra el campeón de la copa continental del otro nivel.
		var cont_wins: Array = honors.duplicate()
		var cw = season.get("cont_won", null)  # copa continental ganada JUGÁNDOLA
		if cw is Dictionary and String(cw.get("conf", "")) != "":
			cont_wins.append({"kind": "continental", "id": "cont_%s_%d" % [cw["conf"], int(cw["tier"])]})
		for h in cont_wins:
			if String(h.get("kind", "")) != "continental":
				continue
			var parts: PackedStringArray = String(h.get("id", "")).split("_")
			if parts.size() < 3:
				continue
			var hconf: String = parts[1]
			var htier: int = int(parts[2])
			if Confederations.tier_count(hconf) < 2:
				continue
			var other_tier: int = 2 if htier == 1 else 1
			var other_champ: String = SeasonReportEngine.cup_champion_club_id(continental_cup_for(hconf, other_tier))
			var sc_name: String = "Supercopa continental (%s)" % Confederations.REGION.get(hconf, hconf)
			if other_champ == "" or other_champ == user_club_id:
				_supercup_defs.append({"kind": "continental", "name": sc_name, "auto": true})
			else:
				_supercup_defs.append({"kind": "continental", "name": sc_name, "opp": other_champ})

		# Primas por título (PrizeMoneyEngine) — se pagan al balance del
		# jugador. Antes NO había ningún ingreso por ganar cosas.
		if not honors.is_empty():
			var lg := _find_league(int(season.get("league_id", -1)))
			var lg_rep: int = lg.reputation if lg != null else 50
			var prize_rng := RandomNumberGenerator.new()
			prize_rng.seed = hash("prize:%d:%s" % [season_year, user_club_id]) ^ world_seed
			var prize: Dictionary = PrizeMoneyEngine.for_honors(honors, lg_rep, prize_rng)
			if int(prize.get("total", 0)) > 0:
				ending_player.balance += int(prize["total"])
				SaveManager.save_player(ending_player)
				last_season_report["prize_money"] = prize
				var detail: String = ""
				for l in prize.get("lines", []):
					detail += "\n· %s: %s" % [String(l["name"]), CurrencyFormat.format(int(l["amount"]))]
				PressGenerator.append_to_feed(ending_player, {
					"headline": "Primas por los títulos de la temporada",
					"body": "Tu parte de las primas del plantel: %s en total.%s" % [CurrencyFormat.format(int(prize["total"])), detail],
					"source": "FINANZAS", "sentiment": "POSITIVE",
				}, current_epoch_day)

		# Ascenso/descenso del club en el que jugó el usuario ESTA temporada
		# (`user_club_id`, misma variable que ya usa el bloque de primas de
		# arriba) -- efecto en dinero pedido explícito por Wilber.
		var pr_move: Dictionary = {}
		for mv in league_moves:
			if String(mv.get("club_id", "")) == user_club_id:
				pr_move = mv
				break
		if not pr_move.is_empty():
			var pr_direction: String = String(pr_move["direction"])
			var pr_rng := RandomNumberGenerator.new()
			pr_rng.seed = hash("promrel:%d:%s" % [season_year, user_club_id]) ^ world_seed
			var pr_amount: int = 0
			if pr_direction == "up":
				var new_lg := _find_league(int(pr_move["to_league_id"]))
				pr_amount = PrizeMoneyEngine.for_promotion(new_lg.reputation if new_lg != null else 50, pr_rng)
			else:
				var old_lg := _find_league(int(pr_move["from_league_id"]))
				pr_amount = PrizeMoneyEngine.for_relegation(old_lg.reputation if old_lg != null else 50, pr_rng)
			ending_player.balance = maxi(ending_player.balance + pr_amount, 0)
			SaveManager.save_player(ending_player)
			last_season_report["promotion_relegation"] = {"direction": pr_direction, "amount": pr_amount}
			PressGenerator.append_to_feed(ending_player, {
				"headline": "¡Ascenso de categoría!" if pr_direction == "up" else "Descenso de categoría",
				"body": "Tu club cambia de categoría la próxima temporada. Efecto en tu bolsillo: %s." % CurrencyFormat.format(pr_amount),
				"source": "FINANZAS", "sentiment": "POSITIVE" if pr_direction == "up" else "NEGATIVE",
			}, current_epoch_day)

	# Aplicar los movimientos de Ascensos/Descensos al mundo VIVO y
	# persistir el historial acumulado (ver nota de v29 en SaveManager.gd)
	# -- world nunca se guarda, así que esto se reaplica también en cada
	# load_runtime().
	if not league_moves.is_empty():
		var league_tier_overrides: Dictionary = SaveManager.load_league_tiers()
		for mv in league_moves:
			league_tier_overrides[String(mv["club_id"])] = int(mv["to_league_id"])
		WorldFactory.apply_league_overrides(world, league_tier_overrides)
		SaveManager.save_league_tiers(league_tier_overrides)

	# `league_id` para la temporada NUEVA -- resuelto ACÁ (después de
	# aplicar Ascensos/Descensos arriba) para que ya refleje la categoría
	# correcta si `club_id` es uno de los clubes movidos esta temporada.
	var league_id: int = int(season.get("league_id", -1))
	var meta: Dictionary = world.get("club_meta_by_id", {}).get(club_id, {})
	if meta.has("league_id"):
		league_id = int(meta["league_id"])

	season = SeasonCalendar.build_season(world, league_id, new_season_start_day, new_start_year, club_id, world_seed, next_rankings)
	season["prev_league_tables"] = prev_league_tables
	season["current_epoch_day"] = current_epoch_day
	user_club_id = club_id
	_apply_supercup_fixtures(_supercup_defs, new_season_start_day)
	_reset_season_stats_and_objective(trophies_gained)
	_check_trait_unlocks()
	_evaluate_captaincy(_prev_captain)
	_refresh_cup()
	_push_transfer_headlines()
	if not last_season_report.is_empty():
		season_ended.emit()

## Rasgos de jugador (schema v21): al cerrar la temporada, con los
## contadores de carrera ya actualizados, mira si se ganó alguno nuevo
## (TraitEngine). Los añade, guarda y publica un titular. Se guardan en
## last_season_report["new_traits"] para que la ceremonia los muestre.
func _check_trait_unlocks() -> void:
	var player := SaveManager.load_player()
	if player == null:
		return
	var unlocked: Array = TraitEngine.check_unlocks(player)
	if unlocked.is_empty():
		return
	for id in unlocked:
		player.traits.append(id)
		PressGenerator.append_to_feed(player, TraitEngine.headline_for(String(id)), current_epoch_day)
	SaveManager.save_player(player)
	last_season_report["new_traits"] = unlocked

## Destitución del DT a mitad de temporada (CoachChangeEngine). Se evalúa
## una vez por temporada dentro de una ventana; si cae, guarda el
## reemplazo en season["coach_replacement"], lo inyecta en el mundo vivo,
## resetea coach_trust y publica el titular.
func _tick_coach_change() -> void:
	if season.is_empty() or user_club_id == "":
		return
	var day_in_season: int = current_epoch_day - int(season.get("season_start_epoch_day", 0))
	if not CoachChangeEngine.should_evaluate(season, day_in_season):
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	var season_start: int = int(season.get("season_start_epoch_day", 0))
	var pos_ratio: float = _league_position_ratio(user_club_id)
	var my_club: ClubData = WorldFactory.find_club(world, user_club_id)
	var exp_ratio: float = CoachChangeEngine.expected_position_ratio(int(my_club.league_ambition) if my_club != null else 50)
	if not CoachChangeEngine.rolls_sacking(world_seed, season_start, pos_ratio, player.coach_trust, exp_ratio):
		season["coach_change_rolled"] = true
		SaveManager.save_season(season)
		return

	var old_coach := WorldFactory.find_coach(world, user_club_id)
	var old_name: String = old_coach.coach_name if old_coach != null else "el entrenador"
	var repl: Dictionary = CoachChangeEngine.make_replacement(user_club_id, world_seed, season_start)
	season["coach_replacement"] = repl
	season["coach_change_rolled"] = true
	SaveManager.save_season(season)
	_reinject_replacement_coach()

	player.coach_trust = CoachChangeEngine.NEW_COACH_TRUST
	PressGenerator.append_to_feed(player, CoachChangeEngine.headline(old_name, String(repl["coach_name"])), current_epoch_day)
	SaveManager.save_player(player)

## Capitanía (CaptaincyEngine): se reevalúa cada temporada con los
## contadores de carrera ya actualizados. Estado no-schema en
## season["is_captain"]. Si es NUEVA, prensa + last_season_report.
func _evaluate_captaincy(was_captain: bool) -> void:
	var player := SaveManager.load_player()
	if player == null:
		return
	var is_captain: bool = CaptaincyEngine.evaluate(player)
	season["is_captain"] = is_captain
	SaveManager.save_season(season)
	if is_captain and not was_captain:
		PressGenerator.append_to_feed(player, CaptaincyEngine.headline(), current_epoch_day)
		last_season_report["captaincy"] = true

const _TRANSFER_SOURCES := ["DEPORTE TOTAL", "GOLAZO TV", "ESTADIO 24", "LA JUGADA", "TRIBUNA", "CANCHA+"]
const _HEADLINES_SHOWN := 6 # de portada en tu feed — el resto de los ~80 fichajes existen igual (afectan fuerza/nómina), solo no todos hacen "noticia"

## Titulares "de portada" del mercado de fichajes REAL de esta temporada
## (ver TransferMarketEngine.generate_season_transfers) — se muestran los
## de mayor nivel primero, con el importe en la moneda que el usuario
## eligió en Ajustes. Se enganchan al feed de prensa ya existente
## (PlayerData.press_feed / scenes/News), sin pantalla nueva.
func _push_transfer_headlines() -> void:
	var player := SaveManager.load_player()
	if player == null:
		return
	var season_start: int = int(season.get("season_start_epoch_day", 0))
	var transfers: Array = TransferMarketEngine.season_transfers_cached(world, world_seed, season_start)
	if transfers.is_empty():
		return

	var order: Dictionary = {"potente": 0, "bueno": 1, "normal": 2, "suave": 3}
	var sorted_transfers: Array = transfers.duplicate()
	sorted_transfers.sort_custom(func(a, b): return int(order.get(a["tier"], 9)) < int(order.get(b["tier"], 9)))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("transfer_press:%d" % season_start) ^ world_seed
	for i in range(mini(_HEADLINES_SHOWN, sorted_transfers.size())):
		var t: Dictionary = sorted_transfers[i]
		var origin: ClubData = WorldFactory.find_club(world, String(t["origin_club_id"]))
		var dest: ClubData = WorldFactory.find_club(world, String(t["destination_club_id"]))
		if origin == null or dest == null:
			continue
		var bidders: Array = t.get("bidders", [])
		var bidder_txt: String = ""
		if not bidders.is_empty():
			var names: Array = []
			for b in bidders:
				var bc: ClubData = WorldFactory.find_club(world, String(b))
				if bc != null:
					names.append(bc.club_name)
			if not names.is_empty():
				bidder_txt = " También pujaron %s, pero se impuso %s." % [", ".join(names), dest.club_name]
		var entry: Dictionary = {
			"headline": "%s ficha por %s" % [String(t["player_name"]), dest.short_name],
			"body": "%s deja %s para firmar con %s por %s.%s" % [
				String(t["player_name"]), origin.club_name, dest.club_name, CurrencyFormat.format(int(t["fee"])), bidder_txt,
			],
			"source": _TRANSFER_SOURCES[rng.randi() % _TRANSFER_SOURCES.size()],
			"sentiment": "NEUTRAL",
		}
		PressGenerator.append_to_feed(player, entry, season_start)
	SaveManager.save_player(player)

## Temporada nueva: contadores a 0 y un objetivo de jugador nuevo (Fase 9,
## backlog "objetivos renovables cada año"). El objetivo del club NO se
## persiste — se deriva en vivo de sus ambiciones (ObjectivesEngine).
func _reset_season_stats_and_objective(trophies_gained: int = 0) -> void:
	var player := SaveManager.load_player()
	if player == null:
		return
	player.career_goals += player.season_goals
	player.career_assists += player.season_key_passes
	# BUG REAL (Wilber: "solo cuenta los partidos como titular y no los
	# partidos jugados en la temporada"): career_matches se etiqueta
	# "Partidos" en varias pantallas (PlayerProfile/Retirement/Social) —
	# acumular desde season_appearances (que en realidad son solo
	# TITULARIDADES) undercontaba el total histórico igual que pasaba a
	# nivel temporada. Ahora se acumula desde season_matches_played (v28).
	player.career_matches += player.season_matches_played  # career_matches nunca se acumulaba: 0 fijo hasta ahora
	player.trophies_won += trophies_gained
	player.season_appearances = 0
	player.season_matches_played = 0
	player.season_goals = 0
	player.season_key_passes = 0
	SaveManager.save_player(player)
	# Acumulador de rendimiento (Σ notas / PJ) para "Premios anuales" —
	# estado no-schema en el dict `season`, se reinicia con la temporada.
	season.erase("user_rating_sum")
	season.erase("user_rating_games")
	season.erase("agent_raise_cd_day") # cooldown de "pedir aumento" (AgentEngine)

	# Sueldos del staff personal por la temporada que termina (StaffEngine).
	# A quien no se le puede pagar, se va.
	var dropped: Array = StaffEngine.pay_season_salaries(player)
	SaveManager.save_player(player)
	if not dropped.is_empty():
		var names: Array = []
		for r in dropped:
			names.append(StaffEngine.META[r]["name"])
		PressGenerator.append_to_feed(player, {
			"headline": "Tu staff se achica",
			"body": "No pudiste pagar el sueldo de: %s." % ", ".join(names),
			"source": "ENTORNO", "sentiment": "CRITICAL",
		}, current_epoch_day)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("objective:%d" % int(season.get("start_year", 0))) ^ world_seed
	season["player_objective"] = ObjectivesEngine.generate_player_objective(player, rng)

## Registra el resultado real del partido que acaba de jugar el usuario
## (liga o copa) y persiste. Llamado desde el Hub al volver del MatchScreen.
## winner_side ("home"/"away") solo importa para copa con empate resuelto
## en penales.
func record_user_result(fixture: Dictionary, home_goals: int, away_goals: int, winner_side: String = "") -> void:
	if season.is_empty():
		return
	match String(fixture.get("competition", "league")):
		"cup":
			if fixture.has("leg"):
				_record_cup_leg(fixture, home_goals, away_goals, winner_side)
			else:
				SeasonEngine.record_user_cup_result(season, fixture, home_goals, away_goals, winner_side)
		"friendly":
			SeasonEngine.record_user_friendly_result(season, fixture, home_goals, away_goals)
		"supercup":
			_record_supercup_result(fixture, home_goals, away_goals, winner_side)
		"cwc":
			_record_cwc_result(fixture, home_goals, away_goals, winner_side)
		"continental":
			_record_continental_result(fixture, home_goals, away_goals, winner_side)
		_:
			SeasonEngine.record_user_league_result(season, fixture, home_goals, away_goals)
	SaveManager.save_season(season)
	_refresh_cup()

func _record_supercup_result(fixture: Dictionary, gh: int, ga: int, winner_side: String) -> void:
	var user_home: bool = String(fixture.get("home_club_id", "")) == user_club_id
	var user_won: bool
	if winner_side != "":
		user_won = (winner_side == "home") == user_home
	else:
		user_won = (gh > ga) == user_home if gh != ga else false
	var kind: String = String(fixture.get("supercup_kind", "domestic"))
	var res: Dictionary = season.get("supercup_results", {})
	res[kind] = {"gh": gh, "ga": ga, "won": user_won}
	season["supercup_results"] = res
	if user_won:
		var p := SaveManager.load_player()
		if p != null:
			_award_supercup_title(p, int(season.get("start_year", get_season_start_year())),
				kind, String(fixture.get("name", "Supercopa nacional")))
			SaveManager.save_player(p)

func is_fixture_played(fixture: Dictionary) -> bool:
	match String(fixture.get("competition", "league")):
		"cup":
			if fixture.has("leg"):
				return season.get("cup_legs", {}).has("%s:%d" % [String(fixture.get("tie_key", "")), int(fixture["leg"])])
			return SeasonEngine.user_has_cup_override(season, fixture)
		"friendly":
			return SeasonEngine.user_has_friendly_override(season, fixture)
		"supercup":
			return season.get("supercup_results", {}).has(String(fixture.get("supercup_kind", "domestic")))
		"cwc":
			return season.get("cwc_results", {}).has(String(fixture.get("cwc_key", "")))
		"continental":
			if String(fixture.get("cont_phase", "")) in ["group", "swiss"]:
				return season.get("cont_results", {}).has(String(fixture.get("cont_key", "")))
			if fixture.has("leg"):
				return season.get("cont_legs", {}).has("%s:%d" % [String(fixture.get("tie_key", "")), int(fixture["leg"])])
			return season.get("cont_results", {}).has(SeasonEngine.cup_result_key(int(fixture.get("round", 0)), String(fixture.get("home_club_id", "")), String(fixture.get("away_club_id", ""))))
		_:
			return SeasonEngine.user_has_override(season, fixture)

## Estado del usuario en la copa (ver SeasonEngine.user_cup_summary).
func user_cup_status() -> Dictionary:
	return SeasonEngine.user_cup_summary(cup, user_club_id)

## O(1) vía world["league_by_id"] (armado en WorldFactory.build(), pulido
## de rendimiento — antes escaneaba las ~55 ligas cada vez, llamada 10
## veces distintas desde este archivo). Fallback defensivo si el mundo no
## trae el índice (mismo criterio que WorldFactory.find_club()).
func _find_league(league_id: int) -> LeagueData:
	var idx: Dictionary = world.get("league_by_id", {})
	if not idx.is_empty():
		return idx.get(league_id, null)
	for l in world.get("leagues", []):
		if l.league_id == league_id:
			return l
	return null

## Fixtures de una liga cualquiera (los ya generados si es la del usuario,
## si no unos deterministas equivalentes) — compartido entre
## table_for_league() y top_performers_for_league(), antes duplicado.
func _fixtures_for_league(league_id: int, clubs: Array) -> Array:
	if not season.is_empty() and int(season.get("league_id", -1)) == league_id:
		return season.get("league_fixtures", [])  # ya generados para la liga del usuario
	var season_start: int = int(season.get("season_start_epoch_day", 0))
	if _fixtures_cache_start != season_start:
		_fixtures_cache.clear()
		_fixtures_cache_start = season_start
	if _fixtures_cache.has(league_id):
		return _fixtures_cache[league_id]
	var lg: LeagueData = _find_league(league_id)
	if lg == null:
		return []
	var ids: Array = clubs.map(func(c): return c.club_id)
	var built: Array = SeasonCalendar.build_league_fixtures(ids, lg, season_start)
	_fixtures_cache[league_id] = built
	return built

## Tarjetas/suspensiones/lesiones de TODA la liga (no solo el usuario) al
## día de hoy — ver DisciplineEngine.gd. `results` viene listo para
## fusionarse con season["results"] como "override": los partidos REALES
## del usuario siempre pisan por encima de la simulación.
func _discipline_for_league(league_id: int, clubs: Array) -> Dictionary:
	if _disc_cache_day != current_epoch_day:
		_disc_cache.clear()
		_disc_cache_day = current_epoch_day
	if _disc_cache.has(league_id):
		return _disc_cache[league_id]
	var clubs_by_id: Dictionary = {}
	for c in clubs:
		clubs_by_id[c.club_id] = c
	var fixtures := _fixtures_for_league(league_id, clubs)
	var sim: Dictionary = DisciplineEngine.simulate_league(
		fixtures, world, clubs_by_id, _strength_by_club, world_seed, current_epoch_day, int(season.get("season_start_epoch_day", 0)),
	)
	_disc_cache[league_id] = sim
	return sim

## Resultados de liga con tarjetas/lesiones ya aplicadas (ver
## DisciplineEngine), fusionados con los partidos REALES del usuario
## (estos últimos siempre ganan el empate de claves).
func _league_results_with_discipline(league_id: int, clubs: Array) -> Dictionary:
	var merged: Dictionary = (_discipline_for_league(league_id, clubs)["results"] as Dictionary).duplicate()
	merged.merge(season.get("results", {}), true)
	return merged

## Prestigio histórico de un club (0..100) para ClubHonorsEngine — combina
## su fuerza actual con la reputación de su liga. Mundo vivo: no persiste.
func club_prestige(club_id: String) -> int:
	if world.is_empty():
		return 40
	var strength: int = int(_strength_by_club.get(club_id, 55))
	var league_rep: int = 50
	var club := WorldFactory.find_club(world, club_id)
	if club != null:
		var lg := _find_league(club.league_id)
		if lg != null:
			league_rep = lg.reputation
	return ClubHonorsEngine.prestige_of(strength, league_rep)

## Vitrina histórica derivada de un club cualquiera.
func club_trophy_cabinet(club_id: String) -> Array:
	if world.is_empty():
		return []
	var strength: int = int(_strength_by_club.get(club_id, 55))
	var league_rep: int = 50
	var club := WorldFactory.find_club(world, club_id)
	if club != null:
		var lg := _find_league(club.league_id)
		if lg != null:
			league_rep = lg.reputation
	var entries: Array = ClubHonorsEngine.for_club(club_id, world_seed, strength, league_rep, get_season_start_year())
	# Trofeo REAL de cada categoría para ESTE club (9-oct: la vitrina
	# mostraba el genérico "mvp_liga" = una estrella MVP para "Liga").
	if club != null:
		var lg2 := _find_league(club.league_id)
		if lg2 != null:
			var conf: String = Confederations.confederation_of(lg2.country)
			for e in entries:
				match String(e.get("id", "")):
					"league":
						e["title_id"] = "league_%d" % lg2.league_id
					"domestic_cup":
						e["title_id"] = "dcup_%s" % lg2.country
					"continental_1":
						e["icon"] = "cont_%s_1" % conf
					"continental_2":
						e["icon"] = "cont_%s_2" % conf
	return entries

## Clasificación al día de hoy de CUALQUIER liga del mundo (mundo vivo).
func table_for_league(league_id: int) -> Array:
	if world.is_empty():
		return []
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return []
	var fixtures := _fixtures_for_league(league_id, clubs)
	var results := _league_results_with_discipline(league_id, clubs)
	return LeagueTable.compute(fixtures, clubs, current_epoch_day, world_seed, results, _strength_by_club)

## Calendario COMPLETO de una liga cualquiera, agrupado por jornada
## (mundo vivo — mismo resultado determinista que table_for_league; los
## partidos REALES del usuario pisan la simulación). Devuelve
## [{matchday:int, epoch_day:int, matches:[{home_id, away_id, played:bool,
##   gh:int, ga:int}]}] ordenado por jornada.
func league_fixture_rounds(league_id: int) -> Array:
	if world.is_empty():
		return []
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return []
	var fixtures := _fixtures_for_league(league_id, clubs)
	var results := _league_results_with_discipline(league_id, clubs)
	var by_md: Dictionary = {}
	for fx in fixtures:
		var md: int = int(fx.get("matchday", 0))
		if not by_md.has(md):
			by_md[md] = {"matchday": md, "epoch_day": int(fx.get("epoch_day", 0)), "matches": []}
		var h: String = String(fx.get("home_club_id", ""))
		var a: String = String(fx.get("away_club_id", ""))
		var played: bool = int(fx.get("epoch_day", 1 << 30)) <= current_epoch_day
		var gh: int = 0
		var ga: int = 0
		if played:
			var key: String = SeasonEngine.league_result_key(md, h, a, int(fx.get("epoch_day", 0)))
			if results.has(key):
				var r: Array = results[key]
				gh = int(r[0])
				ga = int(r[1])
			else:
				var sr: Array = SeasonEngine.league_result(fx, world_seed, {}, _strength_by_club)
				gh = int(sr[0])
				ga = int(sr[1])
		(by_md[md]["matches"] as Array).append({
			"home_id": h, "away_id": a, "played": played, "gh": gh, "ga": ga,
			"epoch_day": int(fx.get("epoch_day", 0)),
		})
	var mds: Array = by_md.keys()
	mds.sort()
	var out: Array = []
	for md in mds:
		out.append(by_md[md])
	return out

## Marcador PROVISIONAL de los demás partidos de la misma jornada de liga
## que `fixture` — para la pantalla de entretiempo ("¿cómo van los otros?").
## NO persiste nada: es el MISMO resultado determinista que ya usa
## table_for_league (SeasonEngine.league_result), mostrado a mitad de
## camino escalándolo por `progress` (0..1). Solo aplica a fixtures de liga;
## para copa/continental devuelve [] (esos van por bracket, fuera de alcance
## acá). Devuelve [{home_name, away_name, gh, ga}].
func other_matchday_scores(fixture: Dictionary, progress: float) -> Array:
	var out: Array = []
	if String(fixture.get("competition", "")) != "league" or world.is_empty():
		return out
	var league_id: int = int(season.get("league_id", -1))
	if league_id < 0:
		return out
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return out
	var by_id: Dictionary = {}
	for c in clubs:
		by_id[c.club_id] = c
	var md: int = int(fixture.get("matchday", -1))
	var my_home: String = String(fixture.get("home_club_id", ""))
	var my_away: String = String(fixture.get("away_club_id", ""))
	var frac: float = clampf(progress, 0.0, 1.0)
	for fx in _fixtures_for_league(league_id, clubs):
		if int(fx.get("matchday", -2)) != md:
			continue
		var h: String = String(fx.get("home_club_id", ""))
		var a: String = String(fx.get("away_club_id", ""))
		if h == my_home and a == my_away:
			continue
		var final_score: Array = SeasonEngine.league_result(fx, world_seed, {}, _strength_by_club)
		out.append({
			"home_id": h,
			"away_id": a,
			"home_name": String(by_id[h].club_name) if by_id.has(h) else h,
			"away_name": String(by_id[a].club_name) if by_id.has(a) else a,
			"gh": int(round(float(final_score[0]) * frac)),
			"ga": int(round(float(final_score[1]) * frac)),
		})
	return out

## Goleadores y asistentes de una liga cualquiera al día de hoy (mundo
## vivo, igual criterio que table_for_league: nada se persiste). Los
## goles de IA se reparten deterministamente entre el once titular de
## cada club (ver TopPerformersEngine) — si el club del usuario es de
## esta liga, sus goles/asistencias REALES (ya registrados en su
## PlayerData) reemplazan la atribución sintética para él.
func top_performers_for_league(league_id: int) -> Dictionary:
	if world.is_empty():
		return {"scorers": [], "assists": []}
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return {"scorers": [], "assists": []}
	var fixtures := _fixtures_for_league(league_id, clubs)
	var clubs_by_id: Dictionary = {}
	for c in clubs:
		clubs_by_id[c.club_id] = c
	var results := _league_results_with_discipline(league_id, clubs)
	var result: Dictionary = TopPerformersEngine.compute_league(
		fixtures, world, clubs_by_id,
		current_epoch_day, world_seed, int(season.get("season_start_epoch_day", 0)), results, _strength_by_club,
	)
	if user_club_id != "" and clubs_by_id.has(user_club_id):
		var player := SaveManager.load_player()
		if player != null:
			TopPerformersEngine.inject_user(result, player, clubs_by_id[user_club_id].club_name)
	return result

## Tabla de amarillas/rojas/lesiones de una liga cualquiera al día de hoy
## — mismo criterio "mundo vivo" que table_for_league/top_performers_for_league.
func discipline_for_league(league_id: int) -> Dictionary:
	if world.is_empty():
		return {"yellow_leaders": [], "red_cards": [], "injuries": []}
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return {"yellow_leaders": [], "red_cards": [], "injuries": []}
	return _discipline_for_league(league_id, clubs)

## Balón de Oro del MUNDO al día de hoy: junta goleadores/asistentes de
## todas las ligas de primera división, los pondera por la reputación de
## su liga (ver BallonDorEngine) y suma bonus por título de liga/copa/
## copa continental — ver BallonDorEngine.gd. Array ordenado de mejor a
## peor, listo para mostrar (name, club_name, goals, assists, trophies,
## score).
var _ballon_dor_cache: Array = []
var _ballon_dor_cache_day: int = -1

## Piso de reputación de liga para entrar en la carrera del Balón de Oro
## (pulido de rendimiento, pedido de Wilber: "la pantalla de vitrina/fin
## de temporada se demora mucho en cargar"). BUG REAL DE FONDO medido con
## `tools/BallonDorTimingProbe.tscn`: esta función recorría las 48 ligas
## de tier 1 del mundo COMPLETAS — 8.8 SEGUNDOS en frío, de los cuales
## 6s son tabla+copa doméstica de esas 48 ligas y 2.4s son goleadores/
## asistentes de cada una (cada una reconstruye el plantel completo de
## sus clubes). Además de lento, no tiene sentido de verdad: en la vida
## real el Balón de Oro lo disputan casi siempre las mismas ~15 ligas de
## élite, nunca alguien de una liga de reputación 48 (Honduras) compite
## de igual a igual. Bajar el piso a este nivel es a la vez MÁS REALISTA
## y ~3× más rápido (menos ligas, y las que quedan afuera tienden a ser
## las más chicas — menos equipos, menos fixtures que armar).
const BALLON_DOR_MIN_LEAGUE_REPUTATION := 70

func ballon_dor_ranking() -> Array:
	if world.is_empty():
		return []
	# Cache por día: recorre las ligas de élite + performers, es caro. El
	# ranking solo cambia al pasar días, así que dentro del mismo día se
	# reutiliza.
	# Bug real de la auditoría: exigir "no vacío" además de "mismo día"
	# anulaba el cache justo cuando el resultado real de ese día ES vacío
	# (temporada muy temprana, sin performers todavía) — se recalculaba
	# entero en cada llamada de ese día. El día ya alcanza: arranca en -1,
	# nunca coincide con current_epoch_day hasta que se computa de verdad.
	if _ballon_dor_cache_day == current_epoch_day:
		return _ballon_dor_cache
	var candidates: Dictionary = {} # "club_name:name" -> row

	for lg in world.get("leagues", []):
		if lg.tier != 1 or lg.reputation < BALLON_DOR_MIN_LEAGUE_REPUTATION:
			continue
		var perf := top_performers_for_league(lg.league_id)
		for row in perf.get("scorers", []):
			_candidate_row(candidates, row, lg.reputation)["goals"] = int(row["count"])
		for row in perf.get("assists", []):
			_candidate_row(candidates, row, lg.reputation)["assists"] = int(row["count"])

		var table := table_for_league(lg.league_id)
		if table.size() > 0:
			_tag_club_players(candidates, table[0]["club_id"], "league_champion")
		if table.size() > 1:
			_tag_club_players(candidates, table[1]["club_id"], "league_runner_up")

		if lg.has_domestic_cup:
			var cup := cup_for_league(lg.league_id)
			var champ_id: String = _final_winner(cup)
			if champ_id != "":
				_tag_club_players(candidates, champ_id, "domestic_cup_champion")

	for confederation in Confederations.ALL:
		var tiers: int = Confederations.tier_count(confederation)
		for tier in range(1, tiers + 1):
			var cup := continental_cup_for(confederation, tier)
			if cup.is_empty():
				continue
			var champ_id: String = _final_winner(cup)
			var runner_id: String = _final_runner_up(cup)
			var champ_key: String = "continental_top_champion" if tier == 1 else "continental_other_champion"
			var runner_key: String = "continental_top_runner_up" if tier == 1 else "continental_other_runner_up"
			if champ_id != "":
				_tag_club_players(candidates, champ_id, champ_key)
			if runner_id != "":
				_tag_club_players(candidates, runner_id, runner_key)

	_ballon_dor_cache = BallonDorEngine.rank(candidates.values())
	_ballon_dor_cache_day = current_epoch_day
	return _ballon_dor_cache

func _candidate_row(candidates: Dictionary, perf_row: Dictionary, league_reputation: int) -> Dictionary:
	# Por id de club cuando lo hay: dos clubes pueden llamarse igual.
	var club_key: String = String(perf_row.get("club_id", "")) if String(perf_row.get("club_id", "")) != "" else String(perf_row["club_name"])
	var key: String = "%s:%s" % [club_key, String(perf_row["name"])]
	if not candidates.has(key):
		candidates[key] = {
			"name": perf_row["name"], "club_name": perf_row["club_name"], "club_id": String(perf_row.get("club_id", "")), "league_reputation": league_reputation,
			"goals": 0, "assists": 0, "trophies": [],
		}
	return candidates[key]

## Bono de título SOLO a los 2 mejores del plantel campeón (por goles +
## asistencias ya sumados), no a todos los que aparecen en alguna lista —
## bug real reportado: un club que ganaba liga + copa + doméstica +
## continental (un triplete) le pegaba el bono completo de LAS TRES a
## cada jugador suyo que hubiera aparecido con una sola asistencia,
## inundando el Balón de Oro con 6 de 10 puestos del mismo club. En la
## vida real un triplete empuja fuerte la candidatura de 1-2 figuras del
## equipo, no la de todo el plantel por igual.
const TROPHY_RECIPIENTS_PER_CLUB := 2

func _tag_club_players(candidates: Dictionary, club_id: String, trophy: String) -> void:
	var club := WorldFactory.find_club(world, club_id)
	if club == null:
		return
	var club_rows: Array = []
	for key in candidates:
		var row: Dictionary = candidates[key]
		var rid: String = String(row.get("club_id", ""))
		if (rid == club_id) if rid != "" else (String(row["club_name"]) == club.club_name):
			club_rows.append(row)
	if club_rows.is_empty():
		return
	club_rows.sort_custom(func(a, b):
		var sa: float = float(a["goals"]) * 2.0 + float(a["assists"]) * 1.5
		var sb: float = float(b["goals"]) * 2.0 + float(b["assists"]) * 1.5
		return sa > sb
	)
	for i in range(mini(TROPHY_RECIPIENTS_PER_CLUB, club_rows.size())):
		(club_rows[i]["trophies"] as Array).append(trophy)

func _final_winner(bracket: Dictionary) -> String:
	for rnd in bracket.get("rounds", []):
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			var matches: Array = rnd.get("matches", [])
			if not matches.is_empty():
				return String(matches[0].get("winner_club_id", ""))
	return ""

func _final_runner_up(bracket: Dictionary) -> String:
	for rnd in bracket.get("rounds", []):
		if String(rnd.get("round_name", "")) == "Final" and rnd.get("decided", false):
			var matches: Array = rnd.get("matches", [])
			if not matches.is_empty():
				var m: Dictionary = matches[0]
				var winner: String = String(m.get("winner_club_id", ""))
				var home: String = String(m.get("home_club_id", ""))
				var away: String = String(m.get("away_club_id", ""))
				return away if winner == home else home
	return ""

## Goleadores y asistentes de la COPA doméstica de una liga cualquiera,
## al día de hoy — solo cuenta rondas ya decididas. Sin inject_user (ver
## TopPerformersEngine.compute_cup): el usuario aparece con la misma
## atribución sintética que cualquier otro jugador de su equipo aquí.
func top_performers_for_cup(league_id: int) -> Dictionary:
	if world.is_empty():
		return {"scorers": [], "assists": []}
	var lg: LeagueData = _find_league(league_id)
	if lg == null:
		return {"scorers": [], "assists": []}
	var resolved_cup := cup_for_league(league_id)
	if resolved_cup.is_empty():
		return {"scorers": [], "assists": []}
	var clubs_by_id: Dictionary = {}
	for cid in SeasonCalendar.country_club_ids(world, lg.country):
		var c := WorldFactory.find_club(world, cid)
		if c != null:
			clubs_by_id[cid] = c
	return TopPerformersEngine.compute_cup(resolved_cup, world, clubs_by_id, world_seed, int(season.get("season_start_epoch_day", 0)))

## Goleadores y asistentes del Mundial de este ciclo (ver
## TopPerformersEngine.compute_national_tournament) — {} si no hay Mundial
## en curso ni resuelto ahora mismo (world_cup_this_cycle() vacío).
func top_performers_for_world_cup() -> Dictionary:
	var wc: Dictionary = world_cup_this_cycle()
	if wc.is_empty():
		return {"scorers": [], "assists": []}
	return TopPerformersEngine.compute_national_tournament(wc, world, world_seed, int(season.get("season_start_epoch_day", 0)))

## Igual que top_performers_for_world_cup() pero para la copa continental
## de selecciones de `confederation` (ver national_cup_for()).
func top_performers_for_national_cup(confederation: String) -> Dictionary:
	var ncup: Dictionary = national_cup_for(confederation)
	if ncup.is_empty():
		return {"scorers": [], "assists": []}
	return TopPerformersEngine.compute_national_tournament(ncup, world, world_seed, int(season.get("season_start_epoch_day", 0)))

## Goleadores y asistentes de la ELIMINATORIA al Mundial de `confederation`
## (pedido de Wilber: fixture/goleador/asistencia también de la
## eliminatoria, no solo del torneo ya armado) — mismo mecanismo que
## top_performers_for_world_cup()/top_performers_for_national_cup(),
## soporta los 2 formatos de QualifyingEngine (tabla única y grupos, ver
## TopPerformersEngine.compute_national_tournament).
func top_performers_for_qualifying(confederation: String) -> Dictionary:
	var resolved: Dictionary = national_qualifying_for(confederation)
	if resolved.is_empty():
		return {"scorers": [], "assists": []}
	return TopPerformersEngine.compute_national_tournament(resolved, world, world_seed, int(season.get("season_start_epoch_day", 0)))

## Cuadro de copa al día de hoy del PAÍS de `league_id` (mundo vivo, igual
## que table_for_league) — cruza TODAS las divisiones de ese país, como
## las copas domésticas reales (Copa del Rey, FA Cup...). Sin overrides de
## usuario salvo que sea el país de su propia liga (ahí ya está cacheado
## en `cup`, con sus resultados reales).
func cup_for_league(league_id: int) -> Dictionary:
	if world.is_empty():
		return {}
	var lg: LeagueData = _find_league(league_id)
	if lg == null or not lg.has_domestic_cup:
		return {}
	if not season.is_empty():
		var my_league: LeagueData = _find_league(int(season.get("league_id", -1)))
		if my_league != null and my_league.country == lg.country:
			return cup
	var ids: Array = SeasonCalendar.country_club_ids(world, lg.country)
	if ids.is_empty():
		return {}
	var template: Dictionary = SeasonCalendar.build_cup_bracket(ids, lg, int(season.get("season_start_epoch_day", 0)))
	# two_legged_until_final=true (auditoría ronda 2): la copa doméstica de
	# CUALQUIER país (menos la final) es ida y vuelta en este juego, igual
	# que la del usuario — antes esto se resolvía siempre a partido único.
	return SeasonEngine.resolve_cup(template, world_seed, _strength_by_club, {}, current_epoch_day, true)

## Liguilla/playoff post-temporada de una liga con LeagueData.has_playoffs
## (MLS, Liga MX, Championship inglés, escocesa, belga...) — {} si esa
## liga no usa playoffs. Mundo vivo: se arma y resuelve de nuevo cada vez
## con la tabla EN VIVO (los primeros de la tabla, según el tamaño de la
## liga, entran a la liguilla).
func playoff_for_league(league_id: int) -> Dictionary:
	if world.is_empty():
		return {}
	var lg: LeagueData = _find_league(league_id)
	if lg == null or not lg.has_playoffs:
		return {}
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return {}
	var table := table_for_league(league_id)
	if table.is_empty():
		return {}
	var n: int = 8 if lg.team_count >= 16 else (6 if lg.team_count >= 10 else 4)
	n = mini(n, table.size())
	var top_ids: Array = []
	for i in range(n):
		top_ids.append(String(table[i]["club_id"]))
	var fixtures := _fixtures_for_league(league_id, clubs)
	var last_day: int = 0
	for fx in fixtures:
		last_day = maxi(last_day, int(fx["epoch_day"]))
	var bracket := SeasonCalendar.build_playoff_bracket(top_ids, "playoff_%d" % league_id, "Liguilla", last_day + 10, 10)
	return SeasonEngine.resolve_cup(bracket, world_seed, _strength_by_club, {}, current_epoch_day)

## UN torneo continental (nivel `tier`, 1-based — Confederations.tier_count
## dice cuántos tiene cada confederación) al día de hoy — mundo vivo,
## igual que cup_for_league: nada se persiste, se arma y resuelve de
## nuevo cada vez con la tabla EN VIVO de cada liga de esa confederación.
## --- Supercopas + Mundial de Clubes (SuperCupEngine) ---
## Todo derivado/determinista, nada se persiste. V1: para mirar en
## Explorar mundo.

func _pool_by_conf() -> Dictionary:
	var out: Dictionary = {}
	for conf in Confederations.ALL:
		out[conf] = []
	for lg in world.get("leagues", []):
		var conf: String = Confederations.confederation_of(lg.country)
		if conf == "" or not out.has(conf):
			continue
		for c in world.get("clubs_by_league", {}).get(lg.league_id, []):
			out[conf].append(c.club_id)
	for conf in out:
		(out[conf] as Array).sort_custom(func(a, b):
			return int(_strength_by_club.get(a, 55)) > int(_strength_by_club.get(b, 55)))
	return out

func _country_pools() -> Dictionary:
	var out: Dictionary = {}
	for lg in world.get("leagues", []):
		var ids: Array = []
		for c in world.get("clubs_by_league", {}).get(lg.league_id, []):
			ids.append(c.club_id)
		if not out.has(lg.country):
			out[lg.country] = {"top": [], "all": []}
		if lg.tier == 1:
			out[lg.country]["top"] = ids.duplicate()
		out[lg.country]["all"].append_array(ids)
	return out

func supercups_this_season() -> Array:
	if world.is_empty():
		return []
	var user_country: String = ""
	var uclub := WorldFactory.find_club(world, user_club_id)
	if uclub != null:
		for lg in world.get("leagues", []):
			if lg.league_id == uclub.league_id:
				user_country = lg.country
				break
	return SuperCupEngine.season_supercups(
		world_seed, get_season_start_year(), _strength_by_club,
		_pool_by_conf(), user_country, _country_pools())

## Supercopa continental de UNA confederación (para WorldExplorer).
func continental_supercup_for(conf: String) -> Dictionary:
	if world.is_empty():
		return {}
	return SuperCupEngine.continental_supercup(
		conf, world_seed, get_season_start_year(), _strength_by_club, _pool_by_conf())

## Supercopa doméstica de UN país (para WorldExplorer).
func domestic_supercup_for(country: String) -> Dictionary:
	if world.is_empty():
		return {}
	return SuperCupEngine.domestic_supercup(
		country, world_seed, get_season_start_year(), _strength_by_club, _country_pools())

func club_world_cup_this_cycle() -> Dictionary:
	if world.is_empty():
		return {}
	return SuperCupEngine.club_world_cup(
		world_seed, get_season_start_year(), _strength_by_club, _pool_by_conf(),
		int(season.get("season_start_epoch_day", 0)), current_epoch_day)

## Eliminatoria al Mundial de UNA confederación (selecciones nacionales,
## Fase 1/5 — para Selections.gd, mismo criterio que continental_cup_for
## con las copas de club: la UI nunca toca _strength_by_club directo).
func national_qualifying_for(confederation: String) -> Dictionary:
	if world.is_empty():
		return {}
	var strength: Dictionary = NationalTeamFactory.strength_by_country(world, _strength_by_club, confederation)
	var overrides: Dictionary = SaveManager.load_international().get("qualifying_results", {})
	var cycle_start: int = _international_cycle_start()
	var windows: Array = _qualifying_windows(cycle_start)
	return QualifyingEngine.resolve(confederation, strength, world_seed, current_epoch_day, cycle_start, overrides, windows)

## Ventanas FIFA reales que caen dentro del ciclo de eliminatorias que
## empieza en `cycle_start` — ver SeasonCalendar.international_windows_in_range
## (BUG real corregido en la Parte 81: antes QualifyingEngine repartía sus
## fechas parejo por los 700 días del ciclo, sin mirar estas ventanas).
## `season.season_start_epoch_day` es el ancla real más reciente conocida.
func _qualifying_windows(cycle_start: int) -> Array:
	if season.is_empty():
		return []
	var known_season_start: int = int(season.get("season_start_epoch_day", 0))
	return SeasonCalendar.international_windows_in_range(cycle_start, cycle_start + QualifyingEngine.CYCLE_QUALIFYING_DAYS, known_season_start)

## Mundial de selecciones de este ciclo, o {} si el año actual no es de
## Mundial (ver WorldCupEngine.is_wc_year).
##
## BUG REAL corregido (Wilber: "miré y había quedado campeón Alemania, a
## la siguiente que miré quedó campeón Argentina y todo el torneo fue
## distinto"): antes esta función recalculaba el pool de clasificados EN
## VIVO en cada llamada, desde la tabla de eliminatoria a `current_epoch_day`
## — como esa tabla sigue evolucionando durante TODO el ciclo de 700 días
## (mundo vivo), el campo de 48 países cambiaba con el correr de los
## días AUNQUE el Mundial ya se hubiera jugado y resuelto — distinto
## campo -> sorteo de grupos distinto -> torneo entero distinto. Ahora el
## campo se CONGELA la primera vez que da 48 países completos
## (`international["wc_field_<año>"]`, mismo patrón "pool congelado una
## vez" que ya usa `season["cont_draw"]` para copas de club) y de ahí en
## más siempre se reusa ese mismo campo para ese año, sin importar cuánto
## seguya evolucionando la eliminatoria de fondo.
##
## El PRIMER Mundial (2026, ya jugado de verdad en la vida real a esta
## altura) usa el campo REAL de 48 países en vez del derivado de una
## eliminatoria recién arrancada (pedido de Wilber: "por qué no haces el
## mundial inicial con las selecciones de este reciente mundial") — ver
## WorldCupEngine.REAL_WC_2026_FIELD. Los siguientes (2030+) sí usan la
## eliminatoria propia del juego, para entonces con temporadas de verdad
## detrás.
func world_cup_this_cycle() -> Dictionary:
	if world.is_empty() or season.is_empty():
		return {}
	var year: int = get_season_start_year()
	if not WorldCupEngine.is_wc_year(year):
		return {}
	var strength: Dictionary = NationalTeamFactory.strength_by_country(world, _strength_by_club)
	var intl: Dictionary = SaveManager.load_international()
	var freeze_key: String = "wc_field_%d" % year
	var frozen_field: Array = (intl[freeze_key] as Array) if intl.has(freeze_key) else []

	if frozen_field.is_empty() and year == WorldCupEngine.WC_BASE_YEAR:
		frozen_field = WorldCupEngine.REAL_WC_2026_FIELD
		intl[freeze_key] = frozen_field
		SaveManager.save_international(intl)

	var pool_by_conf: Dictionary = {}
	if frozen_field.is_empty():
		var qualifying_by_conf: Dictionary = {}
		for conf in Confederations.ALL:
			qualifying_by_conf[conf] = national_qualifying_for(conf)
		pool_by_conf = WorldCupEngine.pool_from_qualifying(qualifying_by_conf)
		var computed_field: Array = WorldCupEngine.field(pool_by_conf)
		if computed_field.size() >= WorldCupEngine.GROUPS * WorldCupEngine.PER_GROUP:
			frozen_field = computed_field
			intl[freeze_key] = frozen_field
			SaveManager.save_international(intl)

	var overrides: Dictionary = intl.get("wc_results", {})
	return WorldCupEngine.resolve(world_seed, year, strength, pool_by_conf, int(season.get("season_start_epoch_day", 0)), current_epoch_day, overrides, frozen_field)

## Copa continental de selecciones de UNA confederación este año, o {} si
## no es su año de copa (ver NationalCupEngine.is_cup_year). Mismo bug
## corregido y mismo criterio de "congelar" que world_cup_this_cycle():
## `qualifying` (la eliminatoria completa que usa NationalCupEngine.field()
## para armar el campo) se recalculaba en vivo cada vez, así que la copa
## continental podía cambiar de campo/campeón después de resuelta. Se
## congela la primera vez que el campo da para al menos 2 grupos (el
## mínimo real para armar un cuadro final, ver NationalCupEngine.resolve).
func national_cup_for(confederation: String) -> Dictionary:
	if world.is_empty() or season.is_empty():
		return {}
	var year: int = get_season_start_year()
	if not NationalCupEngine.is_cup_year(confederation, year):
		return {}
	var strength: Dictionary = NationalTeamFactory.strength_by_country(world, _strength_by_club, confederation)
	var intl: Dictionary = SaveManager.load_international()
	var freeze_key: String = "natcup_qualifying_%s_%d" % [confederation, year]
	var qualifying: Dictionary = intl.get(freeze_key, {})
	if qualifying.is_empty():
		var live_qualifying: Dictionary = national_qualifying_for(confederation)
		if NationalCupEngine.field(confederation, live_qualifying).size() >= 8: # al menos 2 grupos de 4
			qualifying = live_qualifying
			intl[freeze_key] = qualifying
			SaveManager.save_international(intl)
		else:
			qualifying = live_qualifying # campo todavía chico: ni vale la pena congelar, resolve() da {} igual
	var overrides: Dictionary = intl.get("natcup_results", {})
	return NationalCupEngine.resolve(confederation, year, world_seed, strength, qualifying, int(season.get("season_start_epoch_day", 0)), current_epoch_day, overrides)

## --- Títulos de SELECCIÓN (Mundial / copa continental) — Item 2, Parte 82 ---
## Antes ganar el Mundial o la copa continental con tu país no dejaba nada
## en el gabinete de trofeos (HonorsEngine solo detecta títulos de CLUB en
## el rollover de temporada). Se detecta acá, en el tick diario, en vez de
## esperar al rollover: la final puede decidirse DESPUÉS del día 365 de la
## temporada (hallazgo de calendario de la Parte 82 — WorldCupEngine/
## NationalCupEngine spanean bien más allá de SEASON_TOTAL_DAYS en años de
## torneo), así que el rollover a veces ya se perdió la final. Solo cuenta
## si el jugador estaba realmente en el plantel cuando se decidió
## (national_team_status en captain/regular/fringe — no "" ni "left_out").
## Gateado a los ~días de la final (no todo el año) para no resolver el
## cuadro completo a diario sin necesidad.
func _tick_national_trophies() -> void:
	if season.is_empty() or world.is_empty():
		return
	var player := SaveManager.load_player()
	if player == null or player.country == "":
		return
	if not (player.national_team_status in ["captain", "regular", "fringe"]):
		return
	var confederation: String = Confederations.confederation_of(player.country)
	if confederation == "":
		return

	var year: int = get_season_start_year()
	var season_start: int = int(season.get("season_start_epoch_day", 0))
	if WorldCupEngine.is_wc_year(year):
		var final_day: int = season_start + WorldCupEngine.KNOCKOUT_OFFSET + WorldCupEngine.SPAN_TO_FINAL
		if current_epoch_day >= final_day - 2:
			var wc: Dictionary = world_cup_this_cycle()
			if String(wc.get("champion_country", "")) == player.country:
				_award_world_cup_title(player, year)
	elif NationalCupEngine.is_cup_year(confederation, year):
		# Bug real de la auditoría (ronda 3): mezclaba KNOCKOUT_OFFSET de
		# WorldCupEngine (25) con SPAN_TO_FINAL de NationalCupEngine (78) —
		# la compuerta abría ~247 días antes de lo debido (día 101 en vez
		# del 348 real), así que national_cup_for() resolvía el cuadro
		# COMPLETO en cada tick diario durante casi toda la temporada, no
		# solo cerca de la final (el gate de rendimiento documentado más
		# arriba, "para no resolver el cuadro completo a diario sin
		# necesidad", quedaba anulado).
		var final_day2: int = season_start + NationalCupEngine.KNOCKOUT_OFFSET + NationalCupEngine.SPAN_TO_FINAL
		if current_epoch_day >= final_day2 - 2:
			var ncup: Dictionary = national_cup_for(confederation)
			if String(ncup.get("champion_country", "")) == player.country:
				_award_national_cup_title(player, confederation, year)

## Mismo patrón que _award_continental_title/_award_cwc_title: dedupe
## inline por id+season, trophies_won++, bonus de balance, feed de prensa.
func _award_world_cup_title(player: PlayerData, year: int) -> void:
	var key := "world_cup|%d" % year
	for t in player.career_titles:
		if "%s|%d" % [String(t.get("id", "")), int(t.get("season", 0))] == key:
			return
	player.career_titles.append({
		"id": "world_cup", "name": "Copa Mundial %d" % year, "kind": "world", "season": year, "metal": 1,
	})
	player.trophies_won += 1
	player.balance += 45000  # ~45 M€
	PressGenerator.append_to_feed(player, {
		"headline": "¡%s campeón del mundo!" % player.country,
		"body": "%s se corona campeón de la Copa Mundial %d con %s en el plantel." % [player.country, year, player.player_name],
		"source": "DEPORTE TOTAL", "sentiment": "POSITIVE",
	}, current_epoch_day)
	SaveManager.save_player(player)

func _award_national_cup_title(player: PlayerData, confederation: String, year: int) -> void:
	var nm: String = CompetitionNames.national_continental(confederation)
	var key := "natcup_%s|%d" % [confederation, year]
	for t in player.career_titles:
		if "%s|%d" % [String(t.get("id", "")), int(t.get("season", 0))] == key:
			return
	player.career_titles.append({
		"id": "natcup_%s" % confederation, "name": nm, "kind": "continental", "season": year, "metal": 1,
	})
	player.trophies_won += 1
	player.balance += 15000  # ~15 M€
	PressGenerator.append_to_feed(player, {
		"headline": "¡%s campeón de %s!" % [player.country, nm],
		"body": "%s se corona campeón de %s con %s en el plantel." % [player.country, nm, player.player_name],
		"source": "DEPORTE TOTAL", "sentiment": "POSITIVE",
	}, current_epoch_day)
	SaveManager.save_player(player)

## Graba el resultado REAL de un partido de selección jugado por el
## usuario, como override — mismo principio que record_user_result() con
## clubes (WorldTickEngine ya lo hace para liga/copa de club): sin esto,
## la PRÓXIMA consulta a la tabla/cuadro re-simularía ese partido con el
## simulador rápido, dando un resultado DISTINTO al que se jugó de
## verdad (mismo bug de fondo ya arreglado para copas de club, Parte 71).
## `competition`: "qualifying" | "world_cup" | "national_cup" (ver
## MatchState.fixture["competition"], seteado por NationalTeamMatchLauncher).
func record_user_national_result(competition: String, key: String, gh: int, ga: int, winner: String) -> void:
	if key == "":
		return
	var bucket_name: String
	match competition:
		"world_cup": bucket_name = "wc_results"
		"national_cup": bucket_name = "natcup_results"
		_: bucket_name = "qualifying_results"
	var intl: Dictionary = SaveManager.load_international()
	var bucket: Dictionary = intl.get(bucket_name, {})
	bucket[key] = {"score": [gh, ga], "winner": winner}
	intl[bucket_name] = bucket
	SaveManager.save_international(intl)

func continental_cup_for(confederation: String, tier: int = 1) -> Dictionary:
	if world.is_empty():
		return {}
	return ContinentalEngine.build_and_resolve(
		world, confederation, tier, table_for_league, world_seed, _strength_by_club, current_epoch_day,
		int(season.get("season_start_epoch_day", 0)), _rank_by_league_id(confederation),
		season.get("cont_results", {}), _frozen_cont_pool(confederation, tier)
	)

## Sorteo CONGELADO del torneo continental (conf, tier) de esta temporada:
## qué clubes entran y su orden de siembra. Se calcula UNA sola vez —la
## primera que se pide— y queda en season["cont_draw"]; de ahí en más NO
## cambia aunque la tabla de la liga se siga moviendo. Antes se recalculaba
## en cada consulta desde la tabla EN CURSO y por eso los grupos se
## rebarajaban solos (bug reportado por Wilber) y un club que bajaba de
## puesto desaparecía del torneo a mitad de temporada.
func _frozen_cont_pool(confederation: String, tier: int) -> Array:
	if season.is_empty() or world.is_empty():
		return []
	var key: String = "%s_%d" % [confederation, tier]
	# Lista de acceso nueva (ContinentalEngine._ACCESS_PROFILE): un sorteo hecho con
	# el reparto viejo se rehace UNA vez, solo si las copas todavía no arrancaron
	# (sin resultados continentales) — nunca se pisa un torneo a medio jugar.
	if int(season.get("cont_draw_v", 1)) < 2:
		var started: bool = not (season.get("cont_results", {}) as Dictionary).is_empty() 				or current_epoch_day >= int(season.get("season_start_epoch_day", 0)) + ContinentalEngine.CONTINENTAL_START_OFFSET
		if not started:
			season["cont_draw"] = {}
		season["cont_draw_v"] = 2
	var draw: Dictionary = season.get("cont_draw", {})
	if draw.has(key):
		return (draw[key] as Array).duplicate()
	# OJO: NO pasar table_for_league acá — esa da la tabla EN VIVO de ESTE
	# año, y esto se congela el primer día de la temporada (0 partidos
	# jugados, orden de siembra) — la clasificación a copas continentales
	# no tenía ninguna relación real con quién ganó la liga (bug reportado:
	# "salí campeón 6/10 veces y nunca jugué copa continental"). El cupo se
	# gana por la tabla FINAL de la temporada ANTERIOR, como en el fútbol
	# real — ver _prev_season_table_for().
	var pool: Array = ContinentalEngine.qualified_clubs(
		world, confederation, tier, _prev_season_table_for, _strength_by_club, _rank_by_league_id(confederation))
	draw[key] = pool.duplicate()
	season["cont_draw"] = draw
	SaveManager.save_season(season)
	return pool.duplicate()

## Tabla FINAL de la temporada anterior de una liga, en el MISMO formato
## que table_for_league() (filas con "club_id", ordenadas por posición) —
## así qualified_clubs() no necesita saber que esto es "historial" y no
## "en vivo". Se guarda en season["prev_league_tables"] al rollover (ver
## _finish_season_rollover). Si todavía no hay historial (temporada 1 de
## una carrera nueva, o mundo importado recién cargado), aproxima con la
## fuerza de plantilla en vez de una tabla en blanco — mismo criterio que
## CoefficientEngine.bootstrap_rankings() usa para el ranking de países.
func _prev_season_table_for(league_id: int) -> Array:
	var prev: Array = (season.get("prev_league_tables", {}) as Dictionary).get(league_id, [])
	if not prev.is_empty():
		return prev.map(func(cid): return {"club_id": String(cid)})
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	var ids: Array = clubs.map(func(c): return String(c.club_id))
	ids.sort_custom(func(a, b): return float(_strength_by_club.get(a, 50)) > float(_strength_by_club.get(b, 50)))
	return ids.map(func(cid): return {"club_id": cid})

## Posición (1-based) de cada liga tier-1 dentro de su confederación, según
## el ranking VIGENTE de la temporada actual (season["confederation_rankings"],
## armado al rollover con el coeficiente YA CERRADO de la temporada
## anterior — ver ContinentalEngine para por qué usar el de la temporada en
## curso sería circular). Si el save es de antes de que existiera este
## campo (o un mundo importado recién cargado) arranca por reputación al
## vuelo — nunca rompe un save existente.
func _rank_by_league_id(confederation: String) -> Dictionary:
	var order: Array = (season.get("confederation_rankings", {}) as Dictionary).get(confederation, [])
	if order.is_empty():
		order = (CoefficientEngine.bootstrap_rankings(world) as Dictionary).get(confederation, [])
	var rank_map: Dictionary = {}
	for i in range(order.size()):
		rank_map[int(order[i])] = i + 1
	return rank_map

## Ranking global de ligas por coeficiente continental (confederation ->
## Array[{league, score, rank, projected_tier, projected_spots}]) — ver
## CoefficientEngine.gd para el porqué de los puntos, y para qué son los
## cupos proyectados (a qué torneo entraría cada liga la PRÓXIMA temporada
## si hoy se cerrara la tabla en esta posición).
var _coef_cache: Dictionary = {}
var _coef_cache_day: int = -1

func coefficient_ranking() -> Dictionary:
	if world.is_empty():
		return {}
	# Recorre las 55 ligas + tablas: caro. Solo cambia al pasar días.
	# Mismo fix que ballon_dor_ranking(): el día ya alcanza, exigir además
	# "no vacío" anulaba el cache si el resultado real de hoy es {}.
	if _coef_cache_day == current_epoch_day:
		return _coef_cache
	var rank_maps: Dictionary = {}
	for c in Confederations.ALL:
		rank_maps[c] = _rank_by_league_id(c)
	# Ventana de 2 temporadas (pedido explícito de Wilber, ronda 6): se
	# suma el puntaje crudo de la temporada que ya cerró (persistido en
	# _finish_season_rollover) al de esta, en vez de resetear el ranking
	# entero cada año. Si todavía no hay NINGÚN historial guardado (mundo
	# recién creado, antes de terminar su primera temporada), se arranca
	# con un puntaje sembrado por reputación en vez de 0 parejo para las
	# ~55 ligas — pedido explícito de Wilber ("debería ya venir con los
	# puntos que establecen el inicio de temporada").
	var history: Dictionary = SaveManager.load_coefficient_history()
	if history.is_empty():
		history = CoefficientEngine.seed_scores_from_reputation(world)
	_coef_cache = CoefficientEngine.global_ranking(
		world, table_for_league, world_seed, _strength_by_club, current_epoch_day,
		int(season.get("season_start_epoch_day", 0)), rank_maps, _frozen_cont_pool,
		history
	)
	_coef_cache_day = current_epoch_day
	return _coef_cache

## Clasificación de la liga del usuario.
func user_league_table() -> Array:
	if season.is_empty():
		return []
	return table_for_league(int(season.get("league_id", -1)))

func get_season_start_year() -> int:
	# Aprendizaje directo de FL: usar SIEMPRE el año de INICIO de temporada,
	# nunca el año calendario crudo.
	if season.has("start_year"):
		return int(season["start_year"])
	return CalendarUtils.season_start_year(current_epoch_day)

## Día DENTRO de la temporada actual (0 = primer día, se reinicia en cada
## rollover). `current_epoch_day` es un contador global desde el arranque
## de la carrera y NUNCA se reinicia — mostrarlo tal cual en la UI daba
## "Día 373" en la segunda temporada en vez de algo legible (Wilber, Parte
## 92). Única fuente para esta cuenta — no repetir la resta en cada
## pantalla (mismo criterio que `get_season_start_year()`).
func day_in_season() -> int:
	return current_epoch_day - int(season.get("season_start_epoch_day", 0))

# Consultas: delegan en SeasonCalendar (lógica pura y testeable). Se
# mantienen aquí como envoltorio para no esparcir `season` por las pantallas.

## El partido que el usuario TIENE que jugar/simular AHORA: el de hoy, o
## —si se pasó de largo— un partido CONTINENTAL ya vencido y sin jugar.
## La fase de grupos/eliminatoria internacional NO se auto-resuelve para
## el usuario (idea: "JUGAR TODO"); si un save quedó con el día del
## partido en el pasado (p.ej. tras reajustar el calendario), igual hay
## que poder jugarlo — antes `user_fixture_on` exigía epoch_day EXACTO y
## esos partidos quedaban imposibles de jugar (bug reportado por Wilber:
## "me salió en el calendario y cuando llegó el día no me dejó jugarlo").
func pending_user_fixture() -> Dictionary:
	if season.is_empty() or user_club_id == "":
		return {}
	var fx := user_fixture_on(current_epoch_day, user_club_id)
	if not fx.is_empty() and not is_fixture_played(fx):
		return fx
	var cont_fx := _next_user_continental_fixture(user_club_id)
	if not cont_fx.is_empty() and int(cont_fx.get("epoch_day", -1)) <= current_epoch_day \
			and not is_fixture_played(cont_fx):
		return cont_fx
	# Bug real de la auditoría: la ronda 1 de la Copa doméstica (día 49 de
	# temporada) y el arranque de la fase de grupos/liga continental (día
	# 48) caen a menudo el MISMO día tras el ajuste a martes/miércoles/
	# jueves — user_fixture_on() solo ofrece uno (continental, por
	# prioridad) y, a diferencia del continental, la copa doméstica NO
	# tenía este catch-up: una vez que el día exacto pasaba sin jugarla,
	# SeasonEngine.resolve_cup() la terminaba resolviendo sola por RNG sin
	# que el usuario la jugara nunca. Mismo criterio que el continental de
	# arriba: si quedó vencida y sin jugar, ofrecerla igual.
	var ncup_fx := _next_user_cup_fixture(user_club_id)
	if not ncup_fx.is_empty() and int(ncup_fx.get("epoch_day", -1)) <= current_epoch_day \
			and not is_fixture_played(ncup_fx):
		return ncup_fx
	return {}

## Fixture (liga o copa) que involucra a `club_id` en `epoch_day`, o {}.
func user_fixture_on(epoch_day: int, club_id: String) -> Dictionary:
	var cwc_fx := _cwc_user_fixture(club_id, epoch_day)
	if not cwc_fx.is_empty():
		return cwc_fx
	var cont_fx := _next_user_continental_fixture(club_id)
	if not cont_fx.is_empty() and int(cont_fx.get("epoch_day", -1)) == epoch_day:
		return cont_fx
	var sup_fx := supercup_fixture_on(epoch_day, club_id)
	if not sup_fx.is_empty():
		return sup_fx
	var league_fx := SeasonCalendar.fixture_for_club_on(season, epoch_day, club_id)
	if not league_fx.is_empty():
		return league_fx
	var friendly_fx := SeasonCalendar.friendly_fixture_for_club_on(season, epoch_day, club_id)
	if not friendly_fx.is_empty():
		return friendly_fx
	# Copa: puede ser ida o vuelta (la vuelta cae CUP_SECOND_LEG_GAP días
	# después del día nominal de la ronda) — _next_user_cup_fixture ya
	# resuelve qué leg toca; lo devolvemos si cae hoy.
	var ncup := _next_user_cup_fixture(club_id)
	if not ncup.is_empty() and int(ncup.get("epoch_day", -1)) == epoch_day:
		return ncup
	return {}

## Próximo fixture (liga, amistoso O COPA) del usuario a partir de hoy, el
## que caiga antes (para el Hub: "Próximo partido" y el botón de jugar por
## adelantado cuando hoy no toca nada).
func next_user_fixture(club_id: String) -> Dictionary:
	var candidates: Array = []
	var league_fx := SeasonCalendar.next_league_fixture_for_club(season, current_epoch_day, club_id)
	if not league_fx.is_empty():
		candidates.append(league_fx)
	var friendly_fx := SeasonCalendar.next_friendly_for_club(season, current_epoch_day, club_id)
	if not friendly_fx.is_empty():
		candidates.append(friendly_fx)
	var cup_fx := _next_user_cup_fixture(club_id)
	if not cup_fx.is_empty():
		candidates.append(cup_fx)
	var sup_fx := _next_user_supercup_fixture(club_id)
	if not sup_fx.is_empty():
		candidates.append(sup_fx)
	var cwc_fx := _cwc_user_fixture(club_id, -1)
	if not cwc_fx.is_empty():
		candidates.append(cwc_fx)
	var cont_fx := _next_user_continental_fixture(club_id)
	if not cont_fx.is_empty():
		candidates.append(cont_fx)
	if candidates.is_empty():
		return {}
	var best: Dictionary = candidates[0]
	for fx in candidates.slice(1):
		if int(fx["epoch_day"]) < int(best["epoch_day"]):
			best = fx
	return best

## ¿Está abierta la ventana de fichajes de esta temporada? (primeros
## SeasonCalendar.TRANSFER_WINDOW_DAYS desde que arrancó — antes de que
## empiece la liga). Solo informativo/UI: la decisión de renovar o fichar
## del USUARIO ya pasa aparte, en el rollover de temporada.
## Dos ventanas por temporada (pedido explícito): una al arrancar (julio)
## y otra a mitad de temporada (enero, SeasonCalendar
## .MID_SEASON_TRANSFER_WINDOW_OFFSET) — mismo criterio real de mercado
## de verano/invierno.
func is_transfer_window_open() -> bool:
	return is_day_in_transfer_window(current_epoch_day)

## Igual que is_transfer_window_open() pero para CUALQUIER día (no solo
## hoy) — lo usa el Calendario para marcar los días de mercado de meses
## que todavía no llegaron.
func is_day_in_transfer_window(epoch_day: int) -> bool:
	if season.is_empty():
		return false
	var start: int = int(season.get("season_start_epoch_day", 0))
	var elapsed: int = epoch_day - start
	if elapsed >= 0 and elapsed <= SeasonCalendar.TRANSFER_WINDOW_DAYS:
		return true
	var mid: int = SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	return elapsed >= mid and elapsed <= mid + SeasonCalendar.TRANSFER_WINDOW_DAYS

## Próxima ronda de copa YA EMPAREJADA (con ids reales) que involucre al
## club — las rondas más allá de la primera sin decidir todavía no tienen
## rivales conocidos, así que esas se saltan solas (ids vacíos nunca igualan
## a club_id).
## --- Supercopa nacional JUGABLE ---

## Arma los partidos de supercopa (nacional / continental) para la
## temporada nueva. Los `auto` se adjudican de oficio.
func _apply_supercup_fixtures(defs: Array, new_start_day: int) -> void:
	if defs.is_empty():
		return
	var year: int = int(season.get("start_year", get_season_start_year()))
	var fixtures: Array = []
	var offset: int = 6
	for def in defs:
		var kind: String = String(def.get("kind", "domestic"))
		var nm: String = String(def.get("name", "Supercopa"))
		if bool(def.get("auto", false)):
			var p := SaveManager.load_player()
			if p != null:
				_award_supercup_title(p, year, kind, nm)
				PressGenerator.append_to_feed(p, {
					"headline": "%s al bolsillo" % nm,
					"body": "Sin rival distinto que la dispute, la %s es tuya sin jugar." % nm,
					"source": "DEPORTE TOTAL", "sentiment": "POSITIVE",
				}, current_epoch_day)
				SaveManager.save_player(p)
			continue
		fixtures.append({
			"competition": "supercup", "supercup_kind": kind, "name": nm,
			"epoch_day": new_start_day + offset,
			"home_club_id": user_club_id, "away_club_id": String(def.get("opp", "")),
			"is_knockout": true,
		})
		offset += 5
	if not fixtures.is_empty():
		season["supercup_fixtures"] = fixtures

func _award_supercup_title(player: PlayerData, year: int, kind: String = "domestic", nm: String = "Supercopa nacional") -> void:
	var tid: String = "supercopa_cont" if kind == "continental" else "supercopa"
	var key := "%s|%d" % [tid, year]
	for t in player.career_titles:
		if "%s|%d" % [String(t.get("id", "")), int(t.get("season", 0))] == key:
			return
	player.career_titles.append({
		"id": tid, "name": nm, "kind": "team" if kind == "domestic" else "continental", "season": year, "metal": 1,
	})
	player.trophies_won += 1
	player.balance += 3200 if kind == "continental" else 1800

## Fixture de supercopa del usuario en `epoch_day`, o {}.
func supercup_fixture_on(epoch_day: int, club_id: String) -> Dictionary:
	for fx in season.get("supercup_fixtures", []):
		if int(fx.get("epoch_day", -1)) == epoch_day \
				and (fx.get("home_club_id", "") == club_id or fx.get("away_club_id", "") == club_id) \
				and not is_fixture_played(fx):
			return fx
	return {}

func _next_user_supercup_fixture(club_id: String) -> Dictionary:
	for fx in season.get("supercup_fixtures", []):
		if int(fx.get("epoch_day", -1)) >= current_epoch_day \
				and (fx.get("home_club_id", "") == club_id or fx.get("away_club_id", "") == club_id) \
				and not is_fixture_played(fx):
			return fx
	return {}

## --- Copa continental JUGABLE (Champions / Libertadores / etc.) ---
## El usuario juega la fase ELIMINATORIA de su copa continental (la fase
## de grupos/suizo sigue simulada; el usuario clasifica —o no— por la
## tabla del sim). Cruces a doble partido salvo la final.

var _user_cont_cache: Dictionary = {}
var _user_cont_cache_day: int = -1
var _user_cont_cache_res: int = -1

func _user_confederation() -> String:
	var club := WorldFactory.find_club(world, user_club_id)
	if club == null:
		return ""
	var lg := _find_league(club.league_id)
	if lg == null:
		return ""
	return Confederations.confederation_of(lg.country)

func _user_continental() -> Dictionary:
	if world.is_empty() or user_club_id == "":
		return {}
	# Caché por día + tamaño de cont_results (build_and_resolve es caro).
	var res_n: int = (season.get("cont_results", {}) as Dictionary).size()
	if _user_cont_cache_day == current_epoch_day and _user_cont_cache_res == res_n:
		return _user_cont_cache
	var conf: String = _user_confederation()
	if conf == "":
		_user_cont_cache = {}
		_user_cont_cache_day = current_epoch_day
		_user_cont_cache_res = res_n
		return {}
	for tier in range(1, Confederations.tier_count(conf) + 1):
		var cup: Dictionary = ContinentalEngine.build_and_resolve(
			world, conf, tier, table_for_league, world_seed, _strength_by_club, current_epoch_day,
			int(season.get("season_start_epoch_day", 0)), _rank_by_league_id(conf),
			season.get("cont_results", {}), _frozen_cont_pool(conf, tier))
		if cup.is_empty():
			continue
		if _cont_cup_has_club(cup, user_club_id):
			_user_cont_cache = {"conf": conf, "tier": tier, "cup": cup}
			_user_cont_cache_day = current_epoch_day
			_user_cont_cache_res = res_n
			return _user_cont_cache
	_user_cont_cache = {}
	_user_cont_cache_day = current_epoch_day
	_user_cont_cache_res = res_n
	return {}

func _cont_cup_has_club(cup: Dictionary, cid: String) -> bool:
	for g in cup.get("groups", []):
		for r in g.get("standings", []):
			if String(r["club_id"]) == cid:
				return true
	for r in cup.get("league_phase", []):
		if String(r["club_id"]) == cid:
			return true
	for rnd in cup.get("rounds", []):
		for m in rnd.get("matches", []):
			if String(m.get("home_club_id", "")) == cid or String(m.get("away_club_id", "")) == cid:
				return true
	return false

func _next_user_continental_fixture(club_id: String) -> Dictionary:
	var uc: Dictionary = _user_continental()
	if uc.is_empty():
		return {}
	var cup: Dictionary = uc["cup"]
	var results: Dictionary = season.get("cont_results", {})
	var legs: Dictionary = season.get("cont_legs", {})
	var base_meta := {
		"competition": "continental", "cont_conf": uc["conf"], "cont_tier": uc["tier"],
		"cont_name": String(cup.get("cup_name", "Copa continental")),
	}

	# --- Fase de GRUPOS (partido único) ---
	for g in cup.get("groups", []):
		var in_group: bool = false
		for r in g.get("standings", []):
			if String(r["club_id"]) == club_id:
				in_group = true
		if not in_group:
			continue
		for fx in g.get("fixtures", []):
			var h0: String = String(fx.get("home_club_id", ""))
			var a0: String = String(fx.get("away_club_id", ""))
			if h0 != club_id and a0 != club_id:
				continue
			var gkey: String = ContinentalEngine.group_fixture_key(int(g["group_index"]), int(fx["matchday"]), h0, a0)
			if results.has(gkey):
				continue
			var gfx := base_meta.duplicate()
			gfx["cont_phase"] = "group"
			gfx["cont_key"] = gkey
			gfx["round_name"] = "Grupos · J%d" % int(fx["matchday"])
			gfx["epoch_day"] = int(fx["epoch_day"])
			gfx["home_club_id"] = h0
			gfx["away_club_id"] = a0
			gfx["is_knockout"] = false
			return gfx

	# --- Fase de LIGA / suizo (partido único) ---
	for sf in cup.get("swiss_fixtures", []):
		var h1: String = String(sf.get("home", ""))
		var a1: String = String(sf.get("away", ""))
		if h1 != club_id and a1 != club_id:
			continue
		if results.has(String(sf["key"])):
			continue
		var sfx := base_meta.duplicate()
		sfx["cont_phase"] = "swiss"
		sfx["cont_key"] = String(sf["key"])
		sfx["round_name"] = "Fase de liga · J%d" % (int(sf["round"]) + 1)
		sfx["epoch_day"] = int(sf["epoch_day"])
		sfx["home_club_id"] = h1
		sfx["away_club_id"] = a1
		sfx["is_knockout"] = false
		return sfx

	for rnd in cup.get("rounds", []):
		for m in rnd.get("matches", []):
			var h: String = String(m.get("home_club_id", ""))
			var a: String = String(m.get("away_club_id", ""))
			if h != club_id and a != club_id:
				continue
			if results.has(SeasonEngine.cup_result_key(int(rnd["round"]), h, a)):
				continue
			var base := {
				"competition": "continental", "round": int(rnd["round"]),
				"round_name": String(rnd.get("round_name", "")),
				"epoch_day": int(rnd["epoch_day"]), "home_club_id": h, "away_club_id": a,
				"is_knockout": true, "cont_conf": uc["conf"], "cont_tier": uc["tier"],
				"cont_name": String(cup.get("cup_name", "Copa continental")),
			}
			if String(rnd.get("round_name", "")) == "Final":
				return base
			var tie_key: String = "R%d:%s:%s" % [int(rnd["round"]), h, a]
			if not legs.has(tie_key + ":1"):
				var l1 := base.duplicate()
				l1["round_name"] = "%s · Ida" % base["round_name"]
				l1["is_knockout"] = false
				l1["leg"] = 1
				l1["tie_key"] = tie_key
				return l1
			if not legs.has(tie_key + ":2"):
				var l1r: Dictionary = legs[tie_key + ":1"]
				var l2 := base.duplicate()
				l2["round_name"] = "%s · Vuelta" % base["round_name"]
				l2["epoch_day"] = int(rnd["epoch_day"]) + CUP_SECOND_LEG_GAP
				l2["home_club_id"] = a
				l2["away_club_id"] = h
				l2["leg"] = 2
				l2["tie_key"] = tie_key
				l2["leg1_score"] = [int(l1r.get("gh", 0)), int(l1r.get("ga", 0))]
				l2["tie_agg"] = {"home": int(l1r.get("ga", 0)), "away": int(l1r.get("gh", 0))}
				return l2
	return {}

## TODOS los partidos de la copa continental del usuario de esta temporada
## (jugados o no) — para PINTARLOS en el Calendario y la tira semanal del
## Hub. `user_fixture_on()` solo devuelve "el próximo", así que las
## jornadas de grupo/eliminatoria más lejanas quedaban invisibles en esas
## vistas (bug: "en el calendario no salen los partidos de copas
## internacionales"). Cada entrada trae epoch_day + round_name +
## home/away + played.
func user_continental_fixtures(club_id: String = "") -> Array:
	var cid: String = club_id if club_id != "" else user_club_id
	if cid == "":
		return []
	var uc: Dictionary = _user_continental()
	if uc.is_empty():
		return []
	var cup: Dictionary = uc["cup"]
	var results: Dictionary = season.get("cont_results", {})
	var out: Array = []
	var meta := {
		"competition": "continental", "cont_conf": uc["conf"], "cont_tier": uc["tier"],
		"cont_name": String(cup.get("cup_name", "Copa continental")),
	}
	for g in cup.get("groups", []):
		var mine := false
		for r in g.get("standings", []):
			if String(r["club_id"]) == cid:
				mine = true
		if not mine:
			continue
		for fx in g.get("fixtures", []):
			var h := String(fx.get("home_club_id", ""))
			var a := String(fx.get("away_club_id", ""))
			if h != cid and a != cid:
				continue
			var gkey := ContinentalEngine.group_fixture_key(int(g["group_index"]), int(fx["matchday"]), h, a)
			var e := meta.duplicate()
			e["round_name"] = "Grupos · J%d" % int(fx["matchday"])
			e["epoch_day"] = int(fx["epoch_day"])
			e["home_club_id"] = h
			e["away_club_id"] = a
			e["is_knockout"] = false
			e["played"] = results.has(gkey)
			out.append(e)
	for sf in cup.get("swiss_fixtures", []):
		var h1 := String(sf.get("home", ""))
		var a1 := String(sf.get("away", ""))
		if h1 != cid and a1 != cid:
			continue
		var e1 := meta.duplicate()
		e1["round_name"] = "Fase de liga · J%d" % (int(sf["round"]) + 1)
		e1["epoch_day"] = int(sf["epoch_day"])
		e1["home_club_id"] = h1
		e1["away_club_id"] = a1
		e1["is_knockout"] = false
		e1["played"] = results.has(String(sf["key"]))
		out.append(e1)
	for rnd in cup.get("rounds", []):
		for m in rnd.get("matches", []):
			var h2 := String(m.get("home_club_id", ""))
			var a2 := String(m.get("away_club_id", ""))
			if h2 != cid and a2 != cid:
				continue
			var e2 := meta.duplicate()
			e2["round_name"] = String(rnd.get("round_name", ""))
			e2["epoch_day"] = int(rnd["epoch_day"])
			e2["home_club_id"] = h2
			e2["away_club_id"] = a2
			e2["is_knockout"] = true
			e2["played"] = results.has(SeasonEngine.cup_result_key(int(rnd["round"]), h2, a2))
			out.append(e2)
	return out

## Igual pero devuelve solo el partido continental que cae EXACTAMENTE en
## `epoch_day` (o {}), sin importar si ya se jugó — para el pintado por día.
func user_continental_fixture_on(epoch_day: int, club_id: String = "") -> Dictionary:
	for fx in user_continental_fixtures(club_id):
		if int(fx.get("epoch_day", -1)) == epoch_day:
			return fx
	return {}

## CALENDARIO de la fase de grupos / fase de liga (suizo) de un torneo
## continental — jornada a jornada, con TODOS los partidos (no solo los
## del usuario) y su resultado ya resuelto (override del usuario o sim
## determinista de IA, mismo criterio que ContinentalEngine.group_standings
## / swiss_table). Devuelve [{matchday, matches:[{home_id, away_id,
## played, gh, ga}]}]. Para el toggle "Calendario" del WorldExplorer
## (pedido de Wilber: "no vi el fixture en los torneos internacionales").
func continental_fixture_rounds(confederation: String, tier: int = 1) -> Array:
	var cup: Dictionary = continental_cup_for(confederation, tier)
	if cup.is_empty():
		return []
	var results: Dictionary = season.get("cont_results", {})
	var by_md: Dictionary = {}
	for g in cup.get("groups", []):
		for fx in g.get("fixtures", []):
			var h: String = String(fx.get("home_club_id", ""))
			var a: String = String(fx.get("away_club_id", ""))
			if h == "" or a == "":
				continue
			var md: int = int(fx["matchday"])
			var gkey: String = ContinentalEngine.group_fixture_key(int(g["group_index"]), md, h, a)
			if not by_md.has(md):
				by_md[md] = []
			by_md[md].append(_cont_fx_entry(h, a, gkey, int(fx["epoch_day"]), results))
	for sf in cup.get("swiss_fixtures", []):
		var sh: String = String(sf.get("home", ""))
		var sa: String = String(sf.get("away", ""))
		if sh == "" or sa == "":
			continue
		var smd: int = int(sf["round"]) + 1
		if not by_md.has(smd):
			by_md[smd] = []
		by_md[smd].append(_cont_fx_entry(sh, sa, String(sf["key"]), int(sf["epoch_day"]), results))
	var mds: Array = by_md.keys()
	mds.sort()
	var out: Array = []
	for md in mds:
		out.append({"matchday": md, "matches": by_md[md]})
	return out

func _cont_fx_entry(h: String, a: String, key: String, epoch_day: int, results: Dictionary) -> Dictionary:
	var e: Dictionary = {"home_id": h, "away_id": a, "played": false, "gh": 0, "ga": 0, "epoch_day": epoch_day}
	if results.has(key):
		var s: Array = results[key].get("score", [0, 0])
		e["played"] = true
		e["gh"] = int(s[0])
		e["ga"] = int(s[1])
	elif epoch_day <= current_epoch_day:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key) ^ world_seed
		var sc: Array = MatchSimulator.simulate(
			float(_strength_by_club.get(h, 55)), float(_strength_by_club.get(a, 55)), rng)
		e["played"] = true
		e["gh"] = int(sc[0])
		e["ga"] = int(sc[1])
	return e

func _award_continental_title(player: PlayerData, nm: String) -> void:
	var year: int = get_season_start_year()
	var key := "continental_playable|%d" % year
	for t in player.career_titles:
		if "%s|%d" % [String(t.get("id", "")), int(t.get("season", 0))] == key:
			return
	player.career_titles.append({
		"id": "continental_playable", "name": nm, "kind": "continental", "season": year, "metal": 1,
	})
	player.trophies_won += 1
	player.balance += 12000  # ~12 M€

func _record_continental_result(fixture: Dictionary, gh: int, ga: int, winner_side: String) -> void:
	var res: Dictionary = season.get("cont_results", {})
	var nm: String = String(fixture.get("cont_name", "Copa continental"))

	# Fase de grupos / suizo: solo el marcador (la tabla lo recalcula).
	if String(fixture.get("cont_phase", "")) in ["group", "swiss"]:
		res[String(fixture.get("cont_key", ""))] = {"score": [gh, ga]}
		season["cont_results"] = res
		return

	if not fixture.has("leg"):
		# Final a partido único.
		var user_home: bool = String(fixture.get("home_club_id", "")) == user_club_id
		var w: String = winner_side
		if w == "" and gh != ga:
			w = "home" if gh > ga else "away"
		res[SeasonEngine.cup_result_key(int(fixture["round"]), String(fixture["home_club_id"]), String(fixture["away_club_id"]))] = {"score": [gh, ga], "winner": w}
		season["cont_results"] = res
		if (w == "home") == user_home:
			var p := SaveManager.load_player()
			if p != null:
				_award_continental_title(p, nm)
				PressGenerator.append_to_feed(p, {
					"headline": "¡Campeones de %s!" % nm,
					"body": "Tu club levanta la copa continental. Noche histórica.",
					"source": "DEPORTE TOTAL", "sentiment": "POSITIVE",
				}, current_epoch_day)
				SaveManager.save_player(p)
			# Para la Supercopa continental de la temporada que viene.
			season["cont_won"] = {
				"conf": String(fixture.get("cont_conf", "")),
				"tier": int(fixture.get("cont_tier", 1)),
				"name": nm,
			}
		return
	# Ida / vuelta.
	var tie_key: String = String(fixture.get("tie_key", ""))
	var leg: int = int(fixture.get("leg", 1))
	var legs: Dictionary = season.get("cont_legs", {})
	legs["%s:%d" % [tie_key, leg]] = {"gh": gh, "ga": ga}
	season["cont_legs"] = legs
	if leg != 2:
		return
	var parts: PackedStringArray = tie_key.split(":", true, 2)
	if parts.size() < 3:
		return
	var rnum: int = int(String(parts[0]).trim_prefix("R"))
	var h: String = parts[1]
	var a: String = parts[2]
	var l1: Dictionary = legs.get("%s:1" % tie_key, {"gh": 0, "ga": 0})
	var agg_h: int = int(l1["gh"]) + ga
	var agg_a: int = int(l1["ga"]) + gh
	var cw: String
	if agg_h > agg_a:
		cw = "home"
	elif agg_a > agg_h:
		cw = "away"
	else:
		cw = "away" if winner_side == "home" else "home"
	res[SeasonEngine.cup_result_key(rnum, h, a)] = {"score": [agg_h, agg_a], "winner": cw}
	season["cont_results"] = res

## --- Mundial de Clubes JUGABLE (cada 4 años) ---

## Torneo del año en curso, resuelto con los resultados REALES del usuario
## (season["cwc_results"]). {} si no es año de Mundial o el mundo no da.
func cwc_this_season() -> Dictionary:
	if world.is_empty():
		return {}
	return ClubWorldCupEngine.resolve(
		world_seed, get_season_start_year(), _strength_by_club, _pool_by_conf(),
		int(season.get("season_start_epoch_day", 0)), current_epoch_day,
		season.get("cwc_results", {}))

func cwc_user_qualifies() -> bool:
	if world.is_empty() or not ClubWorldCupEngine.is_cwc_season(get_season_start_year()):
		return false
	return ClubWorldCupEngine.club_qualifies(user_club_id, _pool_by_conf())

func _cwc_user_fixture(club_id: String, on_day: int) -> Dictionary:
	if not cwc_user_qualifies():
		return {}
	var fx: Dictionary = ClubWorldCupEngine.next_user_fixture(
		cwc_this_season(), club_id, current_epoch_day, season.get("cwc_results", {}))
	if fx.is_empty():
		return {}
	if on_day >= 0 and int(fx.get("epoch_day", -1)) != on_day:
		return {}
	return fx

func _award_cwc_title(player: PlayerData, year: int) -> void:
	var key := "mundial_clubes|%d" % year
	for t in player.career_titles:
		if "%s|%d" % [String(t.get("id", "")), int(t.get("season", 0))] == key:
			return
	player.career_titles.append({
		"id": "mundial_clubes", "name": "Mundial de Clubes", "kind": "world", "season": year, "metal": 1,
	})
	player.trophies_won += 1
	player.balance += 40000  # ~40 M€ de premio

## Guarda el resultado de una ida/vuelta de copa. En la VUELTA calcula el
## agregado y deja el override del cruce en season["results"] con el
## ganador (por goles totales; si empatan, el que ganó la tanda en la
## vuelta — el motor la corrió porque el fixture llevaba tie_agg).
func _record_cup_leg(fixture: Dictionary, gh: int, ga: int, winner_side: String) -> void:
	var tie_key: String = String(fixture.get("tie_key", ""))
	var leg: int = int(fixture.get("leg", 1))
	var legs: Dictionary = season.get("cup_legs", {})
	legs["%s:%d" % [tie_key, leg]] = {"gh": gh, "ga": ga}
	season["cup_legs"] = legs
	if leg != 2:
		SaveManager.save_season(season)
		return

	var parts: PackedStringArray = tie_key.split(":", true, 2)
	if parts.size() < 3:
		return
	var rnd_num: int = int(String(parts[0]).trim_prefix("R"))
	var h: String = parts[1]
	var a: String = parts[2]
	var l1: Dictionary = legs.get("%s:1" % tie_key, {"gh": 0, "ga": 0})
	# ida en orientación (h,a); vuelta en orientación (a,h)
	var agg_h: int = int(l1["gh"]) + ga   # h marcó de local en la ida + de visitante en la vuelta
	var agg_a: int = int(l1["ga"]) + gh
	var canonical_winner: String
	if agg_h > agg_a:
		canonical_winner = "home"
	elif agg_a > agg_h:
		canonical_winner = "away"
	else:
		# empate global → lo decidió la vuelta (winner_side en orientación a=home, h=away)
		canonical_winner = "away" if winner_side == "home" else "home"
	SeasonEngine.record_user_cup_result(season, {
		"competition": "cup", "round": rnd_num, "home_club_id": h, "away_club_id": a,
	}, agg_h, agg_a, canonical_winner)

func _record_cwc_result(fixture: Dictionary, gh: int, ga: int, winner_side: String) -> void:
	var res: Dictionary = season.get("cwc_results", {})
	var user_home: bool = String(fixture.get("home_club_id", "")) == user_club_id
	var winner: String = winner_side
	if winner == "" and gh != ga:
		winner = "home" if gh > ga else "away"
	res[String(fixture.get("cwc_key", ""))] = {"score": [gh, ga], "winner": winner}
	season["cwc_results"] = res
	# ¿Ganó la final?
	if String(fixture.get("cwc_phase", "")) == "knockout" and String(fixture.get("round_name", "")) == "Final":
		var user_won: bool = (winner == "home") == user_home
		if user_won:
			var p := SaveManager.load_player()
			if p != null:
				_award_cwc_title(p, get_season_start_year())
				PressGenerator.append_to_feed(p, {
					"headline": "¡Campeones del mundo!",
					"body": "Tu club levanta el Mundial de Clubes. El fútbol entero mira para acá.",
					"source": "DEPORTE TOTAL", "sentiment": "POSITIVE",
				}, current_epoch_day)
				SaveManager.save_player(p)

## Días entre la ida y la vuelta de un cruce a doble partido — ÚNICA
## fuente ahora en SeasonEngine.CUP_SECOND_LEG_GAP (auditoría ronda 2:
## esto y resolve_cup() no debían tener cada uno su propio literal 7).
const CUP_SECOND_LEG_GAP := SeasonEngine.CUP_SECOND_LEG_GAP

func _next_user_cup_fixture(club_id: String) -> Dictionary:
	if club_id == "" or cup.is_empty():
		return {}
	for rnd in cup.get("rounds", []):
		for m in rnd.get("matches", []):
			if m.get("home_club_id", "") != club_id and m.get("away_club_id", "") != club_id:
				continue
			var h: String = String(m["home_club_id"])
			var a: String = String(m["away_club_id"])
			# ¿el cruce ya está resuelto? (override en season["results"])
			if season.get("results", {}).has(SeasonEngine.cup_result_key(int(rnd["round"]), h, a)):
				continue
			var base := {
				"competition": "cup", "round": int(rnd["round"]), "round_name": rnd["round_name"],
				"epoch_day": int(rnd["epoch_day"]), "home_club_id": h, "away_club_id": a,
				"is_knockout": true,
			}
			# La FINAL es a partido único. El resto: ida y vuelta.
			if String(rnd["round_name"]) == "Final":
				return base
			var tie_key: String = "R%d:%s:%s" % [int(rnd["round"]), h, a]
			var legs: Dictionary = season.get("cup_legs", {})
			if not legs.has(tie_key + ":1"):
				var l1 := base.duplicate()
				l1["round_name"] = "%s · Ida" % rnd["round_name"]
				l1["is_knockout"] = false
				l1["leg"] = 1
				l1["tie_key"] = tie_key
				return l1
			if not legs.has(tie_key + ":2"):
				var l1r: Dictionary = legs[tie_key + ":1"]
				var l2 := base.duplicate()
				l2["round_name"] = "%s · Vuelta" % rnd["round_name"]
				l2["epoch_day"] = int(rnd["epoch_day"]) + CUP_SECOND_LEG_GAP
				l2["home_club_id"] = a  # se invierte la localía
				l2["away_club_id"] = h
				l2["leg"] = 2
				l2["tie_key"] = tie_key
				# resultado de la ida en orientación (h, a) para el marcador
				l2["leg1_score"] = [int(l1r.get("gh", 0)), int(l1r.get("ga", 0))]
				# acarreo agregado en la orientación de la VUELTA (a=local, h=visitante)
				l2["tie_agg"] = {"home": int(l1r.get("ga", 0)), "away": int(l1r.get("gh", 0))}
				return l2
			# tie ya resuelto (override en season["results"]) → seguir buscando
	return {}

# --- Hooks: implementar en fases sucesivas, igual que FL fases 6-9 ---

func _tick_finances() -> void:
	if season.is_empty() or user_club_id == "" or current_epoch_day % 7 != 0:
		return
	var player := SaveManager.load_player()
	if player == null or player.wage <= 0:
		return
	# Asesor financiero (StaffEngine): un plus a los ingresos semanales.
	player.balance += int(round(ContractEngine.weekly_income(player.wage) * StaffEngine.income_factor(player)))
	# Derechos de imagen (ImageRightsEngine): tu parte de lo que genera tu imagen.
	player.balance += ImageRightsEngine.weekly_income(player)
	SaveManager.save_player(player)

## Resuelve inversiones vencidas (InvestmentEngine) — se acredita el pago
## y sale un titular de prensa con el resultado.
func _tick_investments() -> void:
	var player := SaveManager.load_player()
	if player == null or player.investments.is_empty():
		return
	var matured: Array = InvestmentEngine.resolve_due(player, current_epoch_day, world_seed)
	if matured.is_empty():
		return
	SaveManager.save_player(player)
	for m in matured:
		var gain: int = int(m["gain"])
		var verb: String = "rindió" if gain >= 0 else "cerró en pérdida"
		PressGenerator.append_to_feed(player, {
			"headline": "Tu inversión en %s %s" % [String(m["name"]), verb],
			"body": "Pusiste %s y recuperaste %s (%s%s)." % [
				CurrencyFormat.format(int(m["amount"])), CurrencyFormat.format(int(m["payout"])), "+" if gain >= 0 else "-", CurrencyFormat.format(absi(gain)),
			],
			"source": "FINANZAS", "sentiment": "POSITIVE" if gain >= 0 else "CRITICAL",
		}, current_epoch_day)

func _tick_fixtures() -> void:
	if season.is_empty() or user_club_id == "":
		return
	# OJO: usar SIEMPRE pending_user_fixture() aquí (liga + copa +
	# continental vencido), nunca SeasonCalendar directo — ya se coló un
	# bug por duplicar esta lógica.
	var fx := pending_user_fixture()
	if not fx.is_empty():
		user_match_today.emit(fx)
		return
	# Partido de SELECCIÓN (Parte 91, pedido de Wilber: "los partidos de
	# selección deben ser como los demás, salir en el calendario y
	# jugarse como se juegan los demás, nada distinto") — antes esto
	# NUNCA emitía `user_match_today`, así que el Hub jamás se enteraba
	# de un partido de selección por sí solo: había que entrar a
	# "Selecciones" a mano. Mismo aviso que un partido de club (el Hub
	# distingue el tipo de fixture al lanzarlo, ver Hub._launch_fixture).
	# El calendario de club ya bloquea sus propios fixtures durante la
	# ventana FIFA (SeasonCalendar, desde la Fase 1), así que nunca compite
	# con esto el mismo día.
	var nat_fx := pending_user_national_fixture()
	if not nat_fx.is_empty():
		user_match_today.emit(nat_fx)

## Titular NO ligado al partido del usuario: racha del CLUB en liga (no
## la nota individual del jugador) o narrativa de tramo final de
## temporada (pelea por el título / por no descender). {} si esta semana
## no hay nada que contar (ver _tick_press).
func _club_press_headline(rng: RandomNumberGenerator) -> Dictionary:
	var league_id: int = int(season.get("league_id", -1))
	var clubs: Array = world.get("clubs_by_league", {}).get(league_id, [])
	if clubs.is_empty():
		return {}
	var club: ClubData = WorldFactory.find_club(world, user_club_id)
	var club_name: String = club.club_name if club != null else "Tu club"
	var total_matchdays: int = maxi((clubs.size() - 1) * 2, 1)

	var streak: Dictionary = _club_league_streak(league_id)
	if int(streak.get("count", 0)) >= 4:
		if String(streak["kind"]) == "win":
			return {
				"headline": "%s no conoce la derrota" % club_name,
				"body": "%d triunfos seguidos en liga mantienen a %s en uno de los mejores momentos de la temporada." % [int(streak["count"]), club_name],
				"source": PressGenerator.SOURCES[rng.randi() % PressGenerator.SOURCES.size()], "sentiment": "POSITIVE",
			}
		return {
			"headline": "%s no levanta cabeza" % club_name,
			"body": "%d derrotas seguidas en liga encienden las alarmas alrededor de %s." % [int(streak["count"]), club_name],
			"source": PressGenerator.SENSATIONALIST[rng.randi() % PressGenerator.SENSATIONALIST.size()], "sentiment": "CRITICAL",
		}

	var table: Array = user_league_table()
	if table.is_empty():
		return {}
	var row: Dictionary = LeagueTable.row_for(table, user_club_id)
	if row.is_empty():
		return {}
	var games_left: int = total_matchdays - int(row.get("pj", 0))
	if games_left <= 0 or games_left > 10:
		return {}  # la narrativa de tramo final solo aplica cerca del cierre

	var pos: int = int(row["pos"])
	if pos <= 3:
		var leader: Dictionary = table[0]
		var gap: int = int(leader["pts"]) - int(row["pts"])
		if pos == 1 or gap <= games_left * 2:
			return {
				"headline": "%s se mete de lleno en la pelea por el título" % club_name,
				"body": "A %d jornadas del final, %s está a %d puntos de la cima." % [games_left, club_name, gap],
				"source": PressGenerator.SOURCES[rng.randi() % PressGenerator.SOURCES.size()], "sentiment": "POSITIVE",
			}
	elif pos > table.size() - 3:
		var safe: Dictionary = table[maxi(table.size() - 4, 0)]
		var gap_out: int = int(row["pts"]) - int(safe["pts"])
		return {
			"headline": "%s, metido en la pelea por no descender" % club_name,
			"body": "A %d jornadas del final, %s está a %d puntos de la salvación." % [games_left, club_name, absi(gap_out)],
			"source": PressGenerator.SENSATIONALIST[rng.randi() % PressGenerator.SENSATIONALIST.size()],
			"sentiment": "CRITICAL" if gap_out < 0 else "NEUTRAL",
		}
	return {}

## Racha reciente del CLUB del usuario en LIGA (no la nota individual del
## jugador): victorias o derrotas consecutivas mirando hacia atrás desde
## la última jornada decidida. {"kind": "win"|"loss"|"", "count": int}.
func _club_league_streak(league_id: int) -> Dictionary:
	var rounds: Array = league_fixture_rounds(league_id)
	var seq: Array = []
	for rd in rounds:
		for m in (rd["matches"] as Array):
			if not bool(m["played"]):
				continue
			var is_home: bool = String(m["home_id"]) == user_club_id
			var is_away: bool = String(m["away_id"]) == user_club_id
			if not is_home and not is_away:
				continue
			var gf: int = int(m["gh"]) if is_home else int(m["ga"])
			var gc: int = int(m["ga"]) if is_home else int(m["gh"])
			if gf > gc:
				seq.append(1)
			elif gf < gc:
				seq.append(-1)
			else:
				seq.append(0)
	if seq.is_empty():
		return {"kind": "", "count": 0}
	var last: int = int(seq[seq.size() - 1])
	if last == 0:
		return {"kind": "", "count": 0}
	var count: int = 0
	for i in range(seq.size() - 1, -1, -1):
		if int(seq[i]) != last:
			break
		count += 1
	return {"kind": "win" if last == 1 else "loss", "count": count}

func _tick_press() -> void:
	# La prensa ligada al partido (PressGenerator.headline_for_match) se
	# genera en MatchSummary, justo cuando ya se conocen goles/nota — no
	# aquí, para no recalcular el contexto del partido dos veces. Este
	# hook cubre prensa NO ligada a un partido concreto: racha del CLUB
	# (no del jugador) y narrativa de tramo final de temporada (pelea por
	# el título / por no descender) — Parte 91, pedido de Wilber. Chequeo
	# semanal (no diario, igual que _tick_life_events) para no recalcular
	# la tabla de liga todos los días por algo que solo cambia cada
	# jornada.
	if season.is_empty() or user_club_id == "" or current_epoch_day % 7 != 0:
		return
	var week: int = CalendarUtils.week_index(current_epoch_day)
	if week < int(season.get("club_press_cd_week", -999)):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("club_press:%d" % current_epoch_day) ^ world_seed
	if rng.randf() >= 0.16:
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	var entry: Dictionary = _club_press_headline(rng)
	if entry.is_empty():
		return
	season["club_press_cd_week"] = week + 3
	SaveManager.save_season(season)
	PressGenerator.append_to_feed(player, entry, current_epoch_day)
	SaveManager.save_player(player)

## Aviso de APERTURA y CIERRE de la ventana de fichajes (pedido de Wilber:
## "que el sistema avise que inició o terminó el mercado"). Es un flanco
## puro sobre is_day_in_transfer_window (día de hoy vs ayer), así que
## dispara exactamente una vez por borde sin guardar estado extra. Deja
## una nota en el feed de prensa (persistente) y también en season, para
## que el Hub/Calendario puedan resaltar los días de cierre.
func _tick_transfer_window_news() -> void:
	if season.is_empty():
		return
	var now_in: bool = is_day_in_transfer_window(current_epoch_day)
	var was_in: bool = is_day_in_transfer_window(current_epoch_day - 1)
	if now_in == was_in:
		return
	var start: int = int(season.get("season_start_epoch_day", 0))
	var mid: int = SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	var which: String = "de invierno" if (current_epoch_day - start) >= mid - 2 else "de verano"
	var player := SaveManager.load_player()
	if player == null:
		return
	if now_in and not was_in:
		season["transfer_window_open"] = true
		PressGenerator.append_to_feed(player, {
			"headline": "Se abre el mercado de fichajes %s" % which,
			"body": "Arranca la ventana de traspasos. Durante las próximas %d semanas puede haber movimientos, ofertas y salidas." % int(round(SeasonCalendar.TRANSFER_WINDOW_DAYS / 7.0)),
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)
	elif was_in and not now_in:
		season.erase("transfer_window_open")
		PressGenerator.append_to_feed(player, {
			"headline": "Cierra el mercado de fichajes %s" % which,
			"body": "Se acabó la ventana de traspasos. Hasta la próxima no se pueden cerrar más operaciones.",
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)
	SaveManager.save_season(season)
	SaveManager.save_player(player)

## `true` si `day` cae dentro de alguna ventana FIFA de la temporada
## actual (selecciones nacionales, Fase 2) — ver SeasonCalendar.
## international_windows_for_season. Mismo rol que
## is_day_in_transfer_window, pero para selección.
func is_day_in_international_window(day: int) -> bool:
	if season.is_empty():
		return false
	var start: int = int(season.get("season_start_epoch_day", 0))
	for w in SeasonCalendar.international_windows_for_season(start):
		if day >= int(w[0]) and day <= int(w[1]):
			return true
	return false

## Días hasta que arranque la PRÓXIMA ventana FIFA, o -1 si no hay ninguna
## dentro de los próximos `lookahead` días (o la temporada termina antes,
## ver nota de is_day_in_international_window: solo mira las ventanas de
## LA TEMPORADA ACTUAL, así que no cruza el rollover — aceptable, es
## nomás un aviso anticipado, no una fuente de verdad). Para el aviso del
## Hub ("se viene una fecha FIFA"): antes las ventanas solo se veían
## el día que llegaban (Calendar.gd, Parte 82), sin anticipo en el Hub
## donde el jugador pasa la mayoría del tiempo.
func days_until_next_international_window(lookahead: int = 6) -> int:
	if season.is_empty():
		return -1
	if is_day_in_international_window(current_epoch_day):
		return -1  # ya estás EN la ventana — la avisa Calendar.gd, no hace falta "viene"
	var season_end: int = int(season.get("season_start_epoch_day", 0)) + SeasonCalendar.season_length_days(get_season_start_year())
	var last_day: int = mini(current_epoch_day + lookahead, season_end)
	for day in range(current_epoch_day + 1, last_day + 1):
		if is_day_in_international_window(day):
			return day - current_epoch_day
	return -1

## Epoch_day en que arranca la TEMPORADA del año de Mundial `year` — ancla
## real del ciclo de eliminatorias (ver _international_cycle_start()).
func _wc_season_start_epoch_day(year: int) -> int:
	return CalendarUtils.date_to_epoch_day(year, CalendarUtils.SEASON_START_MONTH, 1)

## Ciclo de eliminatorias al Mundial (~2 años, QualifyingEngine.
## CYCLE_QUALIFYING_DAYS) — anclado en el guardado "international"
## (schema v26), NUNCA en `season` (que se reconstruye entera cada 365
## días).
##
## BUG REAL corregido (Wilber, Parte 93: "las eliminatorias se jugaron 2
## veces, por qué?"): antes el ciclo arrancaba en el día 0 y se reiniciaba
## SOLO cada CYCLE_QUALIFYING_DAYS (~1.9 años) sin parar nunca, sin mirar
## cuándo cae el próximo Mundial DE VERDAD (cada 4 años, ~1460 días —
## WorldCupEngine.is_wc_year). En ese hueco de 4 años entre dos Mundiales
## cabían DOS ciclos completos de eliminatoria en vez de uno solo. Ahora el
## ciclo SIEMPRE termina justo cuando arranca la temporada del año de
## Mundial, y no hay ciclo nuevo hasta ~2 años antes del SIGUIENTE Mundial
## — el hueco de por medio, como en la vida real (entre Mundiales no hay
## eliminatoria corriendo).
func _international_cycle_start() -> int:
	var year: int = WorldCupEngine.WC_BASE_YEAR
	while current_epoch_day >= _wc_season_start_epoch_day(year):
		year += 4
	var start: int = maxi(_wc_season_start_epoch_day(year) - QualifyingEngine.CYCLE_QUALIFYING_DAYS, 0)

	var intl: Dictionary = SaveManager.load_international()
	if int(intl.get("cycle_start_epoch_day", -1)) != start:
		intl["cycle_start_epoch_day"] = start
		intl["user_callup_status"] = {}
		SaveManager.save_international(intl)
	return start

## Convocatoria a la selección (selecciones nacionales, Fase 2) — flanco
## puro de APERTURA de ventana FIFA (mismo criterio que
## _tick_transfer_window_news(): dispara una vez por borde, sin guardar
## estado extra de "qué día es"). Recalcula la convocatoria ENTERA por
## MÉRITO cada vez (NationalCallUpEngine.gd) — nunca una relación
## persistente, podés quedar afuera si tu nivel/forma no acompañan. Deja
## una nota en prensa. NO lanza ningún partido acá — eso es
## pending_user_national_fixture(), consultado bajo demanda (mismo
## criterio que continental_cup_for() con las copas de club).
func _tick_international_window() -> void:
	if season.is_empty() or world.is_empty():
		return
	var now_in: bool = is_day_in_international_window(current_epoch_day)
	var was_in: bool = is_day_in_international_window(current_epoch_day - 1)
	if not (now_in and not was_in):
		return
	var player := SaveManager.load_player()
	if player == null or player.country == "":
		return
	var confederation: String = Confederations.confederation_of(player.country)
	if confederation == "":
		return

	var season_start: int = int(season.get("season_start_epoch_day", 0))
	var result: Dictionary
	# Bug real de la auditoría (ronda 3): la convocatoria se resolvía SOLO
	# por mérito, sin mirar si estás lesionado — un DT real no llama a un
	# jugador que no puede jugar. Sin esto, podías salir "convocado como
	# capitán" en la prensa mientras Hub.gd tenía Jugar/Simular
	# deshabilitados por la lesión, sin ninguna explicación de la
	# contradicción.
	if player.injury_days_remaining > 0:
		result = {"called_up": false, "status": "injured", "probability": 0.0}
	else:
		var pool: Array[PlayerData] = NationalTeamFactory.squad_for(world, world_seed, season_start, player.country, player)
		var recent_form: float = NationalCallUpEngine.recent_form_from_rating(float(season.get("user_rating_sum", 0.0)), int(season.get("user_rating_games", 0)))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("callup:%s:%d" % [player.country, current_epoch_day]) ^ world_seed
		result = NationalCallUpEngine.resolve(player, pool, recent_form, rng)

	player.national_team_status = String(result["status"])
	var called_up: bool = bool(result["called_up"])
	var headline: String
	var body: String
	if called_up:
		headline = "Convocado como capitán de la selección" if String(result["status"]) == "captain" else "Convocado a la selección"
		body = "%s recibe el llamado de %s para esta fecha FIFA." % [player.player_name, player.country]
	elif String(result["status"]) == "injured":
		headline = "Se queda afuera de la convocatoria por lesión"
		body = "%s no puede ser convocado por %s mientras se recupera de su lesión." % [player.player_name, player.country]
	else:
		headline = "Se queda afuera de la convocatoria"
		body = "El cuerpo técnico de %s no lo/la incluye en la nómina para esta fecha FIFA." % player.country
	PressGenerator.append_to_feed(player, {
		"headline": headline, "body": body,
		"source": "SELECCIÓN", "sentiment": "POSITIVO" if called_up else "NEUTRAL",
	}, current_epoch_day)
	SaveManager.save_player(player)

	var intl: Dictionary = SaveManager.load_international()
	intl["user_callup_status"] = {
		"window_start_day": current_epoch_day, "called_up": called_up,
		"status": String(result["status"]), "probability": float(result["probability"]),
		"seen": false, # pedido de Wilber: "que salga un popup con la invitación" — ver Hub._refresh_callup_button()/scenes/NationalCallUp
	}
	SaveManager.save_international(intl)

## Tu partido de selección HOY, si te convocaron esta ventana y hay
## fixture — {} el resto de los días (la inmensa mayoría; las ventanas
## FIFA son cortas). A diferencia de pending_user_fixture(), NO forma
## parte del tick diario: se consulta BAJO DEMANDA, mismo criterio que
## continental_cup_for() con las copas de club. Mira, en orden, el
## Mundial (si es su año y tu país está adentro), la copa continental de
## tu confederación (si es su año) y la eliminatoria (lo más frecuente) —
## nunca los tres a la vez el mismo día por construcción de los
## calendarios de cada motor. Devuelve {opponent, is_home, epoch_day,
## confederation, competition, key, is_knockout, user_start_chance} o {}.
## Fixture de selección del país para cualquier fecha programada, aunque el
## usuario no haya sido convocado. El calendario usa esto para mostrar el
## partido; `pending_user_national_fixture()` decide si puede jugarlo.
func user_national_fixture_on(epoch_day: int) -> Dictionary:
	if season.is_empty() or world.is_empty():
		return {}
	var player := SaveManager.load_player()
	if player == null or player.country == "":
		return {}
	var confederation: String = Confederations.confederation_of(player.country)
	if confederation == "":
		return {}
	var intl: Dictionary = SaveManager.load_international()
	var callup: Dictionary = intl.get("user_callup_status", {})
	var called_up := epoch_day == current_epoch_day and bool(callup.get("called_up", false))
	var user_start_chance := float(callup.get("probability", 0.0)) if called_up else 0.0

	var wc: Dictionary = world_cup_this_cycle()
	if not wc.is_empty():
		var wc_fx: Dictionary = WorldCupEngine.next_user_fixture(wc, player.country, epoch_day, intl.get("wc_results", {}))
		if not wc_fx.is_empty():
			var normalized_wc := _normalize_national_fixture(wc_fx, player.country, confederation, user_start_chance)
			normalized_wc["called_up"] = called_up
			normalized_wc["callup_status"] = String(callup.get("status", "left_out"))
			return normalized_wc

	var ncup: Dictionary = national_cup_for(confederation)
	if not ncup.is_empty():
		var ncup_fx: Dictionary = NationalCupEngine.next_user_fixture(ncup, player.country, epoch_day, intl.get("natcup_results", {}))
		if not ncup_fx.is_empty():
			var normalized_ncup := _normalize_national_fixture(ncup_fx, player.country, confederation, user_start_chance)
			normalized_ncup["called_up"] = called_up
			normalized_ncup["callup_status"] = String(callup.get("status", "left_out"))
			return normalized_ncup

	var cycle_start: int = _international_cycle_start()
	var strength: Dictionary = NationalTeamFactory.strength_by_country(world, _strength_by_club, confederation)
	var resolved: Dictionary = QualifyingEngine.resolve(confederation, strength, world_seed, epoch_day, cycle_start, intl.get("qualifying_results", {}), _qualifying_windows(cycle_start))
	var fx: Dictionary = QualifyingEngine.user_fixture_today(resolved, player.country, epoch_day)
	if fx.is_empty():
		return {}
	fx["confederation"] = confederation
	fx["competition"] = "qualifying"
	if not fx.has("is_knockout"):
		fx["is_knockout"] = false
	fx["user_start_chance"] = user_start_chance
	fx["called_up"] = called_up
	fx["callup_status"] = String(callup.get("status", "left_out"))
	return fx


## Partido nacional de hoy solo si hubo convocatoria; los demás se resuelven
## por la simulación determinista de Mundial/copa/eliminatoria.
func pending_user_national_fixture() -> Dictionary:
	var intl: Dictionary = SaveManager.load_international()
	if not bool(intl.get("user_callup_status", {}).get("called_up", false)):
		return {} # no gastes en resolver eliminatorias si no hay convocatoria
	var fx := user_national_fixture_on(current_epoch_day)
	if fx.is_empty() or not bool(fx.get("called_up", false)):
		return {}
	return fx
## WorldCupEngine.next_user_fixture()/NationalCupEngine.next_user_fixture()
## devuelven home_country/away_country (formato de "cuadro"); acá se
## normaliza a la misma forma opponent/is_home que ya usan Selections.gd/
## NationalTeamMatchLauncher para las 3 competiciones por igual.
func _normalize_national_fixture(fx: Dictionary, user_country: String, confederation: String, user_start_chance: float) -> Dictionary:
	var is_home: bool = String(fx.get("home_country", "")) == user_country
	return {
		"opponent": String(fx.get("away_country", "")) if is_home else String(fx.get("home_country", "")),
		"is_home": is_home, "epoch_day": int(fx.get("epoch_day", current_epoch_day)),
		"confederation": confederation, "competition": String(fx.get("competition", "qualifying")),
		"key": String(fx.get("key", fx.get("wc_key", ""))), "is_knockout": bool(fx.get("is_knockout", false)),
		"user_start_chance": user_start_chance,
	}

## Ofertas que vencen y contraofertas que el club responde (P5) — DIARIO.
func _tick_offer_deadlines() -> void:
	if season.is_empty() or TransferOfferEngine.inbox(season).is_empty():
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	var ctr_rng := RandomNumberGenerator.new()
	ctr_rng.seed = hash("counter:%d" % current_epoch_day) ^ world_seed
	var news: Array = TransferOfferEngine.daily_tick(season, player, current_epoch_day, ctr_rng)
	SaveManager.save_season(season)
	if news.is_empty():
		return
	for n in news:
		PressGenerator.append_to_feed(player, {
			"headline": String(n["headline"]), "body": String(n["body"]),
			"source": "MERCADO", "sentiment": String(n["sentiment"]),
		}, current_epoch_day)
	SaveManager.save_player(player)

func _tick_life_events() -> void:
	if season.is_empty() or user_club_id == "" or current_epoch_day % 7 != 0:
		return
	var player := SaveManager.load_player()
	if player == null:
		return

	var changed: bool = false
	# Vida social (v33): el ánimo vuelve a su base, la afinidad con quien no
	# ves baja un poco.
	SocialLifeEngine.weekly_tick(player)
	changed = true
	if not player.sponsor.is_empty():
		player.balance += int(player.sponsor.get("weekly_income", 0))
		var weeks_left: int = int(player.sponsor.get("weeks_remaining", 0)) - 1
		if weeks_left <= 0:
			SponsorEngine.remove_gift(player)
			player.sponsor = {}
		else:
			player.sponsor["weeks_remaining"] = weeks_left
		changed = true
	elif player.pending_sponsor_offer.is_empty():
		var club_strength: int = int(_strength_by_club.get(user_club_id, 55))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("sponsor:%d" % current_epoch_day) ^ world_seed
		if rng.randf() < SponsorEngine.offer_chance(club_strength, player.overall):
			var so: Dictionary = SponsorEngine.generate_offer(player, rng)
			player.pending_sponsor_offer = so
			changed = true
			# Aviso en la prensa (además del botón del Hub): "que el juego
			# te avise cuando llega un patrocinio" — pedido de Wilber.
			PressGenerator.append_to_feed(player, {
				"headline": "%s quiere ficharte como imagen" % String(so.get("name", "Una marca")),
				"body": "Ofrecen %s por semana durante %d semanas. Revisá la propuesta en el Inicio." % [
					CurrencyFormat.format(int(so.get("weekly_income", 0))), int(so.get("weeks_remaining", 0))],
				"source": "MERCADO", "sentiment": "POSITIVE",
			}, current_epoch_day)

	# Patrocinio de GUAYOS (schema v32): independiente del general.
	var boot_rng := RandomNumberGenerator.new()
	boot_rng.seed = hash("boots:%d" % current_epoch_day) ^ world_seed
	var boot_news: String = BootDealEngine.weekly_tick(player, boot_rng)
	if boot_news != "":
		changed = true
		PressGenerator.append_to_feed(player, {
			"headline": boot_news,
			"body": "Revisá la propuesta en el Inicio." if not player.pending_boot_offer.is_empty() else "Ya podés escuchar otras marcas.",
			"source": "MERCADO", "sentiment": "POSITIVE",
		}, current_epoch_day)

	# Independiente del patrocinio (los dos pueden rolear la misma semana):
	# mejora de sueldo que el club propone solo, ver WageOfferEngine.gd.
	# COOLDOWN de 14 semanas entre propuestas — antes se rolaba cada semana
	# sin memoria y el club te ofrecía subir el sueldo 4 veces en una
	# temporada (reporte de Wilber). Máximo ~2 por temporada.
	var wage_week: int = CalendarUtils.week_index(current_epoch_day)
	if player.pending_wage_offer.is_empty() and wage_week >= int(season.get("wage_offer_cd_week", -999)):
		var wage_rng := RandomNumberGenerator.new()
		wage_rng.seed = hash("wage_offer:%d" % current_epoch_day) ^ world_seed
		if wage_rng.randf() < WageOfferEngine.offer_chance(player.coach_trust, player.contract_years_remaining, player.career_matches):
			var ratio: float = _league_position_ratio(player.club_id)
			var offer: Dictionary = WageOfferEngine.generate_offer(player, ratio)
			if not offer.is_empty():
				player.pending_wage_offer = offer
				season["wage_offer_cd_week"] = wage_week + 14
				SaveManager.save_season(season)
				changed = true

	# También independiente: evento inesperado de temporada (0-3 veces por
	# temporada, ver SeasonEventEngine.gd) — bueno o malo, de aviso o de
	# decisión.
	if player.pending_season_event.is_empty():
		var events_used: int = int(season.get("random_events_used", 0))
		var event_rng := RandomNumberGenerator.new()
		event_rng.seed = hash("season_event:%d" % current_epoch_day) ^ world_seed
		if SeasonEventEngine.should_offer(events_used, event_rng):
			player.pending_season_event = SeasonEventEngine.generate_event(event_rng)
			season["random_events_used"] = events_used + 1
			changed = true

	# El CLUB quiere cederte (pedido de Wilber: "si mi equipo quiere
	# cederme, que me llegue una notificación"). Solo si sos joven y no
	# jugás (misma condición que LoanEngine.can_request). Se avisa en la
	# prensa y aparece el selector de destino en Traspasos. Caduca a los
	# ~21 días si no decidís (cuesta un poco de confianza del DT).
	var clw_week: int = CalendarUtils.week_index(current_epoch_day)
	if not season.has("club_loan_offer") \
			and clw_week >= int(season.get("club_loan_cooldown_week", -999)) \
			and LoanEngine.can_request(player, season, current_epoch_day):
		var clw_rng := RandomNumberGenerator.new()
		clw_rng.seed = hash("club_loan:%d" % current_epoch_day) ^ world_seed
		if clw_rng.randf() < 0.11:
			season["club_loan_offer"] = {"day": current_epoch_day, "deadline_day": current_epoch_day + 21}
			SaveManager.save_season(season)
			var clw_club: ClubData = WorldFactory.find_club(world, user_club_id)
			var clw_name: String = clw_club.club_name if clw_club != null else "Tu club"
			PressGenerator.append_to_feed(player, {
				"headline": "%s te quiere ceder a préstamo" % clw_name,
				"body": "El club cree que necesitás minutos y propone una cesión de una temporada. Elegí destino en Traspasos.",
				"source": "MERCADO", "sentiment": "NEUTRAL",
			}, current_epoch_day)
	elif season.has("club_loan_offer") and current_epoch_day > int(season["club_loan_offer"].get("deadline_day", current_epoch_day)):
		season.erase("club_loan_offer")
		season["club_loan_cooldown_week"] = clw_week + 8
		player.coach_trust = clampi(player.coach_trust - 4, 0, 100)
		changed = true
		SaveManager.save_season(season)
		PressGenerator.append_to_feed(player, {
			"headline": "Se enfría la idea de la cesión",
			"body": "No diste una respuesta y el club deja de insistir con el préstamo, por ahora.",
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)

	# Oferta de otro club por el usuario (puede llegar FUERA de la ventana;
	# se ejecuta al abrir la próxima — ver TransferOfferEngine.gd).
	var toe_rng := RandomNumberGenerator.new()
	toe_rng.seed = hash("transfer_offer:%d" % current_epoch_day) ^ world_seed
	if TransferOfferEngine.should_offer(player, current_epoch_day, season, toe_rng):
		var offer: Dictionary = TransferOfferEngine.generate_offer(
			player, world, world_seed, current_epoch_day, next_transfer_window_day(), toe_rng, season)
		if not offer.is_empty():
			var club_bo: int = int(world.get("club_meta_by_id", {}).get(player.club_id, {}).get("base_overall", 60))
			var counter: Dictionary = {}
			# Si el jugador PIDIÓ salir y el club abrió la veda, el club ya no
			# bloquea la venta (TransferRequestEngine).
			var move_requested: bool = not TransferRequestEngine.active(season, current_epoch_day).is_empty()
			if not move_requested and player.pending_wage_offer.is_empty() and TransferOfferEngine.club_blocks_sale(player, club_bo, offer, toe_rng):
				counter = WageOfferEngine.generate_offer(player, user_league_position_ratio())
			if not counter.is_empty():
				# El club NO te vende: rechaza la oferta y te pone sobre la
				# mesa una mejora de contrato (vos decidís — ver WageOffer).
				counter["reason"] = "counter_interest"
				counter["suitor_name"] = String(offer.get("from_club_name", "otro club"))
				player.pending_wage_offer = counter
				changed = true
				SaveManager.save_season(season)  # persiste recent_suitors
				var my_club: ClubData = WorldFactory.find_club(world, player.club_id)
				var my_name: String = my_club.club_name if my_club != null else "Tu club"
				PressGenerator.append_to_feed(player, {
					"headline": "%s rechaza una oferta por %s" % [my_name, Nickname.press_name(player, world_seed)],
					"body": "%s se interesó en el jugador, pero %s no piensa venderlo y le ofrece mejorar el contrato." % [String(offer.get("from_club_name", "Un club")), my_name],
					"source": "MERCADO", "sentiment": "POSITIVE",
				}, current_epoch_day)
			else:
				TransferOfferEngine.add_to_inbox(season, offer, current_epoch_day)
				SaveManager.save_season(season)

	# Rumor del agente: si estás en racha pero NO hay nada concreto sobre la
	# mesa (ni oferta de traspaso en el buzón, ni mejora de contrato, ni
	# cesión), el agente "filtra" a la prensa que hay clubes preguntando.
	# Es solo ambiente — no genera oferta — pero hace sentir que el agente
	# trabaja entre bambalinas. Cooldown de 5 semanas para no spamear.
	var rumor_week: int = CalendarUtils.week_index(current_epoch_day)
	var nothing_on_table: bool = player.pending_wage_offer.is_empty() \
			and player.pending_season_event.is_empty() \
			and not season.has("club_loan_offer") \
			and TransferOfferEngine.inbox(season).is_empty()
	var goal_rate: float = float(player.season_goals) / maxf(1.0, float(player.season_appearances))
	var hot_form: bool = player.season_appearances >= 4 \
			and (goal_rate >= 0.45 or player.coach_trust >= 74)
	if nothing_on_table and hot_form \
			and rumor_week >= int(season.get("agent_rumor_cd_week", -999)):
		var rumor_rng := RandomNumberGenerator.new()
		rumor_rng.seed = hash("agent_rumor:%d" % current_epoch_day) ^ world_seed
		if rumor_rng.randf() < 0.09:
			season["agent_rumor_cd_week"] = rumor_week + 5
			SaveManager.save_season(season)
			var rumor_lines: Array = [
				"El agente de %s reconoce llamadas de varios clubes, aunque asegura que \"no hay nada firmado\".",
				"Fuentes cercanas a %s hablan de sondeos desde el extranjero. Su club, tranquilo por ahora.",
				"En los pasillos del mercado suena el nombre de %s. De momento, solo rumores.",
			]
			var rumor_body: String = String(rumor_lines[rumor_rng.randi() % rumor_lines.size()]) % player.player_name
			PressGenerator.append_to_feed(player, {
				"headline": "%s, en la órbita de varios clubes" % Nickname.press_name(player, world_seed),
				"body": rumor_body,
				"source": "MERCADO", "sentiment": "NEUTRAL",
			}, current_epoch_day)
			changed = true

	if changed:
		SaveManager.save_player(player)

## Día en que abre la próxima ventana de fichajes (para ejecutar ahí las
## ofertas aceptadas). Si ya estamos dentro de una, devuelve hoy.
func next_transfer_window_day() -> int:
	var start: int = int(season.get("season_start_epoch_day", 0))
	if is_day_in_transfer_window(current_epoch_day):
		return current_epoch_day
	var mid_start: int = start + SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
	if current_epoch_day < mid_start:
		return mid_start
	# Pasada la de media temporada -> la pretemporada de la que viene.
	return start + SeasonCalendar.season_length_days(get_season_start_year()) + 1

## BUG REAL corregido (Wilber, Parte 93: "cambié de club a mitad de
## temporada y el juego se bugeó, solo me sale la tabla de mi ex equipo y
## no me salen partidos con el nuevo equipo"). Causa raíz: season["league_id"]
## y season["league_fixtures"]/["cup"] se arman UNA sola vez al empezar la
## temporada (SeasonCalendar.build_season, en _finish_season_rollover) y
## nunca se tocaban de nuevo — un fichaje a mitad de temporada solo
## cambiaba player.club_id/user_club_id, pero la tabla y el calendario
## seguían siendo los del club VIEJO el resto de la temporada. Si el club
## nuevo está en OTRA liga, se reconstruyen liga+copa para la liga nueva
## (mismo season_start_epoch_day — determinista, reproduce exactamente el
## calendario que esa liga "siempre tuvo" esta temporada); si es la MISMA
## liga, no hace falta tocar nada (el fixture ya incluye a todos los
## clubes, el usuario simplemente empieza a seguir los partidos de su club
## nuevo dentro del mismo listado). `results` (lo YA jugado, de cualquier
## club/competencia) NUNCA se toca — sigue intacto.
func _rebuild_season_for_new_club(new_club_id: String) -> void:
	var meta: Dictionary = world.get("club_meta_by_id", {})
	var new_league_id: int = int(meta.get(new_club_id, {}).get("league_id", -1))
	if new_league_id < 0 or new_league_id == int(season.get("league_id", -1)):
		return
	var start_year: int = int(season.get("start_year", get_season_start_year()))
	var season_start: int = int(season.get("season_start_epoch_day", 0))
	var rankings: Dictionary = season.get("confederation_rankings", {})
	var fresh: Dictionary = SeasonCalendar.build_season(world, new_league_id, season_start, start_year, new_club_id, world_seed, rankings)
	if fresh.is_empty():
		return
	season["league_id"] = fresh["league_id"]
	season["league_fixtures"] = fresh["league_fixtures"]
	season["cup"] = fresh["cup"]

## Fichaje de mitad de temporada recién ejecutado → el Hub muestra la
## presentación oficial (PlayerPresentation) y lo vacía. No se persiste.
var pending_presentation: Dictionary = {}

## Precontrato (PreContractEngine): en tu último año de contrato, desde el
## mercado de invierno, un club puede ofrecerte irte libre a final de
## temporada. Cada día caduca la oferta vieja; una vez por semana puede
## llegar una nueva.
func _tick_precontract() -> void:
	if season.is_empty() or user_club_id == "":
		return
	var gone: String = PreContractEngine.expire_if_due(season, current_epoch_day)
	var weekly: bool = current_epoch_day % 7 == 5
	if gone == "" and not weekly:
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	if gone != "":
		PressGenerator.append_to_feed(player, {
			"headline": "%s retira su oferta de precontrato" % gone,
			"body": "No hubo respuesta y el club busca otras opciones.",
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("precontract:%d" % current_epoch_day) ^ world_seed
	if weekly and PreContractEngine.should_offer(player, season, current_epoch_day, rng):
		var o: Dictionary = PreContractEngine.build_offer(player, world, world_seed, current_epoch_day, rng, season)
		if not o.is_empty():
			season["precontract_offer"] = o
			season["precontract_week"] = CalendarUtils.week_index(current_epoch_day)
			PressGenerator.append_to_feed(player, {
				"headline": "%s ofrece un precontrato a %s" % [String(o.get("from_club_name", "Un club")), Nickname.press_name(player, world_seed)],
				"body": "Le queda medio año de contrato: podría irse libre en verano. Tiene %d días para responder." % PreContractEngine.OFFER_DAYS,
				"source": "MERCADO", "sentiment": "POSITIVE",
			}, current_epoch_day)
	SaveManager.save_season(season)
	SaveManager.save_player(player)

## Último día de mercado y ofertas del Golfo (DeadlineDayEngine): el día de
## cierre de cada ventana puede llegar una oferta urgente que vence ese día;
## una vez por semana, si eres veterano o estrella, puede llegar una oferta
## millonaria de una liga del Golfo.
func _tick_deadline_day() -> void:
	if season.is_empty() or user_club_id == "":
		return
	var is_deadline: bool = DeadlineDayEngine.is_deadline_day(current_epoch_day, season)
	var weekly: bool = current_epoch_day % 7 == 3
	if not is_deadline and not weekly:
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("deadline_day:%d" % current_epoch_day) ^ world_seed
	var pname: String = Nickname.press_name(player, world_seed)
	var free_slot: bool = TransferOfferEngine.pending(season).is_empty() and TransferOfferEngine.inbox(season).size() < TransferOfferEngine.MAX_INBOX
	free_slot = free_slot and PreContractEngine.signed(season).is_empty()
	if is_deadline:
		PressGenerator.append_to_feed(player, {
			"headline": "Deadline day: hoy cierra el mercado",
			"body": "Último día de la ventana. Las operaciones que se cierren hoy se firman sobre la bocina.",
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)
		var requested: bool = not TransferRequestEngine.active(season, current_epoch_day).is_empty()
		if free_slot and rng.randf() < DeadlineDayEngine.deadline_chance(player, requested):
			var gulf: bool = DeadlineDayEngine.gulf_eligible(player, world) and rng.randf() < 0.3
			var o: Dictionary = {}
			if gulf:
				o = DeadlineDayEngine.gulf_offer(player, world, current_epoch_day, current_epoch_day, rng, true)
			else:
				o = DeadlineDayEngine.deadline_offer(player, world, world_seed, current_epoch_day, rng, season)
			if not o.is_empty():
				if gulf:
					DeadlineDayEngine.note_gulf(season, current_epoch_day)
				TransferOfferEngine.add_to_inbox(season, o, current_epoch_day)
				PressGenerator.append_to_feed(player, {
					"headline": "Bombazo de última hora: %s va a por %s" % [String(o.get("from_club_name", "Un club")), pname],
					"body": "Oferta urgente en el último día de mercado. Hay que responder hoy.",
					"source": "MERCADO", "sentiment": "POSITIVE",
				}, current_epoch_day)
	elif free_slot and DeadlineDayEngine.should_gulf(player, world, season, current_epoch_day, rng):
		var g: Dictionary = DeadlineDayEngine.gulf_offer(player, world, current_epoch_day, next_transfer_window_day(), rng, false)
		if not g.is_empty():
			DeadlineDayEngine.note_gulf(season, current_epoch_day)
			TransferOfferEngine.add_to_inbox(season, g, current_epoch_day)
			PressGenerator.append_to_feed(player, {
				"headline": "Oferta millonaria desde el Golfo para %s" % pname,
				"body": "%s pone sobre la mesa un sueldo de %s por temporada. ¿Dinero o ambición deportiva?" % [String(g.get("from_club_name", "Un club")), CurrencyFormat.format(int(g.get("wage", 0)))],
				"source": "MERCADO", "sentiment": "NEUTRAL",
			}, current_epoch_day)
	SaveManager.save_season(season)
	SaveManager.save_player(player)

## Ejecuta una oferta de traspaso/cesión aceptada, si estamos en ventana.
func _tick_pending_transfer() -> void:
	if season.is_empty() or user_club_id == "":
		return
	if TransferOfferEngine.pending(season).is_empty():
		return
	var bell: bool = DeadlineDayEngine.closes_after_bell(TransferOfferEngine.pending(season), current_epoch_day)
	if not is_transfer_window_open() and not bell:
		return
	var player := SaveManager.load_player()
	if player == null:
		return
	var res: Dictionary = TransferOfferEngine.execute_pending(player, season, world)
	if res.get("ok", false):
		# Presentación oficial pendiente: la muestra el Hub la próxima vez
		# que se abre (solo en memoria — no es estado de guardado).
		pending_presentation = {"club_id": player.club_id, "years": player.contract_years_remaining,
			"loan": bool(res.get("loan", false)) or String(res.get("message", "")).to_lower().contains("cedid")}
		user_club_id = player.club_id
		_rebuild_season_for_new_club(player.club_id)
		SaveManager.save_player(player)
		SaveManager.save_season(season)
		PressGenerator.append_to_feed(player, {
			"headline": res["message"], "body": String(res.get("extra", "")) if String(res.get("extra", "")) != "" else ("Cerrado sobre la bocina, en el último día de mercado." if bell else "Movimiento cerrado en la ventana de fichajes."),
			"source": "MERCADO", "sentiment": "NEUTRAL",
		}, current_epoch_day)
		SaveManager.save_player(player)

## Oferta de guayos (BootOfferPanel) aceptada / rechazada.
func resolve_boot_offer(accepted: bool) -> void:
	var player := SaveManager.load_player()
	if player == null or player.pending_boot_offer.is_empty():
		return
	if accepted:
		BootDealEngine.accept(player, player.pending_boot_offer)
	player.pending_boot_offer = {}
	SaveManager.save_player(player)

## Llamado desde SponsorOffer al aceptar/rechazar la oferta pendiente.
func resolve_sponsor_offer(accepted: bool) -> void:
	var player := SaveManager.load_player()
	if player == null or player.pending_sponsor_offer.is_empty():
		return
	if accepted:
		player.sponsor = player.pending_sponsor_offer.duplicate(true)
		SponsorEngine.grant_gift(player)
	player.pending_sponsor_offer = {}
	SaveManager.save_player(player)

## Llamado desde WageOffer al aceptar/rechazar la mejora de sueldo
## pendiente (ver WageOfferEngine.gd) — rechazar no tiene castigo, es una
## mejora que el club ofrece por su cuenta, no una exigencia del jugador.
func resolve_wage_offer(accepted: bool) -> void:
	var player := SaveManager.load_player()
	if player == null or player.pending_wage_offer.is_empty():
		return
	if accepted:
		player.wage = int(player.pending_wage_offer.get("new_wage", player.wage))
	player.pending_wage_offer = {}
	SaveManager.save_player(player)

## Llamado desde WageOffer al pedir más sobre la mejora pendiente (pedido
## de Wilber: "debería ser una propuesta para negociar", ver
## WageOfferEngine.negotiate_counter) — UN solo pedido: si ya se negoció
## esta oferta, no hace nada (WageOffer.gd oculta el botón en ese caso).
## Actualiza `new_wage` en el mismo dict si el club cede; si se planta,
## la oferta original queda tal cual, sin castigo.
func negotiate_wage_offer() -> void:
	var player := SaveManager.load_player()
	if player == null or player.pending_wage_offer.is_empty() or bool(player.pending_wage_offer.get("negotiated", false)):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = WageOfferEngine.negotiate_counter(player.pending_wage_offer, player.agent_stars, player.coach_trust, rng, player.overall)
	player.pending_wage_offer["negotiated"] = true
	player.pending_wage_offer["club_held_firm"] = not bool(result.get("accepted", false))
	if bool(result.get("accepted", false)):
		player.pending_wage_offer["new_wage"] = int(result.get("counter_wage", player.pending_wage_offer["new_wage"]))
	SaveManager.save_player(player)

## Llamado desde SeasonEvent al elegir una opción del evento pendiente
## (ver SeasonEventEngine.gd) — `option_index` es la posición elegida en
## pending_season_event["options"], sus efectos ya vienen sorteados desde
## que el evento se generó.
func resolve_season_event(option_index: int) -> void:
	var player := SaveManager.load_player()
	if player == null or player.pending_season_event.is_empty():
		return
	var options: Array = player.pending_season_event.get("options", [])
	if option_index >= 0 and option_index < options.size():
		SeasonEventEngine.apply_effects(player, options[option_index].get("resolved_effects", {}))
	player.pending_season_event = {}
	SaveManager.save_player(player)

func _tick_fatigue_and_development() -> void:
	if season.is_empty() or user_club_id == "":
		return
	var player := SaveManager.load_player()
	if player == null:
		return

	var changed: bool = false
	if player.injury_days_remaining > 0:
		player.injury_days_remaining = maxi(0, player.injury_days_remaining - 1)
		changed = true

	# Recuperación diaria de energía física. La sube de golpe ir a eventos
	# de la sección de Mensajes (SocialEngine.accept_event); acá vuelve a
	# bajar unos puntos por día de descanso. Mientras esté alta, penaliza un
	# poco las decisiones del partido (MatchEngine._carried_fatigue_penalty).
	# El nutricionista / psicólogo del staff (StaffEngine) suman puntos de
	# recuperación por día encima del ritmo base.
	# Solo se recupera energía en día de DESCANSO. Entrenar la deja igual
	# (ni gasta ni recupera) — la estamina solo baja jugando partidos.
	if player.fatigue_physical > 0.0 and last_day_activity != "train":
		var phys_rec: float = daily_energy_recovery(player)
		player.fatigue_physical = maxf(0.0, player.fatigue_physical - phys_rec)
		changed = true
	# Tensión mental: la suben derrotas / malos partidos (MatchSummary),
	# baja algo más lento que la física con el descanso.
	if player.fatigue_mental > 0.0:
		var ment_rec: float = FATIGUE_MENTAL_DAILY_RECOVERY + StaffEngine.mental_recovery_bonus(player) + RelationshipEngine.mental_recovery_bonus(player)
		player.fatigue_mental = maxf(0.0, player.fatigue_mental - ment_rec)
		changed = true

	if current_epoch_day % 7 == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("dev:%d" % current_epoch_day) ^ world_seed
		var boosted: bool = bool(player.active_effects.get("training_boost", false))
		PlayerDevelopment.apply_weekly_development(player, get_training_focus(), rng, boosted)
		if boosted:
			player.active_effects.erase("training_boost") # Suplemento de concentración: un solo uso
		changed = true

	if changed:
		SaveManager.save_player(player)

## Foco de entrenamiento de la semana: "physical" | "technical" | "mental"
## | "balanced" (por defecto). Solo decide QUÉ atributos reciben el
## cambio semanal — el ritmo de progresión vive solo en PlayerDevelopment.
func get_training_focus() -> String:
	return season.get("training_focus", "balanced")

func get_training_intensity() -> String:
	return String(season.get("training_intensity", "normal"))

func set_training_intensity(intensity: String) -> void:
	if season.is_empty():
		return
	season["training_intensity"] = intensity
	SaveManager.save_season(season)

func set_training_focus(focus: String) -> void:
	if season.is_empty():
		return
	season["training_focus"] = focus
	SaveManager.save_season(season)


## Premios de la temporada QUE TERMINÓ (solo en memoria): la ceremonia los
## deja acá antes de borrar el reporte, así Premios (flujo de fin de
## temporada) muestra los ganadores reales y no la temporada nueva vacía.
var final_awards: Array = []
var final_awards_year: int = 0
