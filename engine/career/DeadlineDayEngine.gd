extends RefCounted
class_name DeadlineDayEngine

## Último día de mercado ("deadline day") y ofertas millonarias de las ligas
## del Golfo (tipo Arabia). Se apoya en TransferOfferEngine para armar la
## oferta base (club, rol, cláusula) y solo cambia lo que tiene de especial:
##
## - DEADLINE DAY: el último día de cada ventana puede llegar una oferta
##   urgente, con algo más de traspaso. Vence ese mismo día y, si la aceptas,
##   se cierra "sobre la bocina" al pasar el día (aunque la ventana ya cerró).
## - OFERTA DEL GOLFO: un club rico de una liga emergente paga muy por encima
##   de lo normal (rompe a propósito el techo de ContractEngine.wage_ceiling) y
##   añade una prima de fichaje; a cambio, tu reputación deportiva baja al
##   firmar. Llegan a jugadores veteranos o ya consagrados.
##
## Estado en `season` (aditivo, sin cambio de esquema):
##   season["gulf_offer_week"] -> semana de la última oferta del Golfo (respiro)
##   la oferta en sí vive en season["transfer_inbox"] con "deadline"/"gulf".

## Ligas que pagan como las del Golfo (ids de WorldFactory).
const GULF_LEAGUES := [18, 46]
## Oferta en el último día: probabilidad base (escala con la reputación).
const DEADLINE_CHANCE := 0.45
const DEADLINE_FEE_MULT := Vector2(1.1, 1.35)
## Oferta del Golfo: probabilidad semanal y respiro entre una y otra.
const GULF_WEEKLY_CHANCE := 0.05
const GULF_COOLDOWN_WEEKS := 12
const GULF_MIN_AGE := 27
const GULF_MIN_OVERALL := 74
const GULF_STAR_OVERALL := 84 # a esta media te buscan a cualquier edad
## Sueldo: múltiplo del techo normal de tu media (y nunca menos que 2,5x lo que cobras).
const GULF_WAGE_MULT := Vector2(1.5, 2.3)
const GULF_FEE_MULT := Vector2(1.2, 1.8)
const GULF_BONUS_OF_WAGE := 0.35 # prima de fichaje: un tercio largo del sueldo anual
const GULF_REP_COST := 6

## ¿Hoy es el último día de una ventana de fichajes?
static func is_deadline_day(day: int, season: Dictionary) -> bool:
	if season.is_empty():
		return false
	var elapsed: int = day - int(season.get("season_start_epoch_day", 0))
	var w: int = SeasonCalendar.TRANSFER_WINDOW_DAYS
	return elapsed == w or elapsed == SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET + w

## ¿Le pueden llegar ofertas del Golfo a este jugador?
static func gulf_eligible(player: PlayerData, world: Dictionary) -> bool:
	if player == null or player.club_id == "":
		return false
	var lid: int = int(world.get("club_meta_by_id", {}).get(player.club_id, {}).get("league_id", -1))
	if lid in GULF_LEAGUES:
		return false
	if player.overall >= GULF_STAR_OVERALL:
		return true
	return player.age >= GULF_MIN_AGE and player.overall >= GULF_MIN_OVERALL

## Probabilidad de la oferta urgente del último día.
static func deadline_chance(player: PlayerData, requested_exit: bool) -> float:
	if requested_exit:
		return 0.85
	var rep: float = clampf(float(player.reputation - TransferOfferEngine.REP_FLOOR) / 45.0, 0.1, 1.3)
	return clampf(DEADLINE_CHANCE * rep, 0.05, 0.6)

## Oferta urgente del último día (o {} si no se pudo armar). Vence hoy.
static func deadline_offer(player: PlayerData, world: Dictionary, world_seed: int, day: int, rng: RandomNumberGenerator, season: Dictionary) -> Dictionary:
	var o: Dictionary = TransferOfferEngine.generate_offer(player, world, world_seed, day, day, rng, season)
	if o.is_empty():
		return {}
	if String(o.get("kind", "")) != "cesión":
		o["fee"] = int(int(o.get("fee", 0)) * rng.randf_range(DEADLINE_FEE_MULT.x, DEADLINE_FEE_MULT.y))
	_mark_deadline(o, day)
	return o

## Convierte una oferta en "de último día": vence hoy, sin contraoferta.
static func _mark_deadline(o: Dictionary, day: int) -> void:
	o["deadline"] = true
	o["window_day"] = day
	o["countered"] = true # no hay tiempo para contraofertas
	o["created_day"] = day - TransferOfferEngine.OFFER_DAYS + 1 # days_left = 1 (vence al pasar el día)

## Oferta del Golfo (o {} si no hay club). `deadline` = llega el último día.
static func gulf_offer(player: PlayerData, world: Dictionary, day: int, next_window_day: int, rng: RandomNumberGenerator, deadline: bool) -> Dictionary:
	var by_league: Dictionary = world.get("clubs_by_league", {})
	var meta: Dictionary = world.get("club_meta_by_id", {})
	var cands: Array = []
	for lid in GULF_LEAGUES:
		for c in by_league.get(lid, []):
			if c.club_id != player.club_id:
				cands.append(c)
	if cands.is_empty():
		return {}
	# Los más fuertes del Golfo son los que tiran la casa por la ventana.
	cands.sort_custom(func(a, b): return int(meta.get(a.club_id, {}).get("base_overall", 0)) > int(meta.get(b.club_id, {}).get("base_overall", 0)))
	var club: ClubData = cands[rng.randi() % mini(4, cands.size())]
	var value: int = player.market_value if player.market_value > 0 else TransferMarketEngine.market_value(player.overall, player.potential, player.age)
	var wage: int = maxi(int(ContractEngine.wage_ceiling(player.overall) * rng.randf_range(GULF_WAGE_MULT.x, GULF_WAGE_MULT.y)), int(player.wage * 2.5))
	var o := {
		"id": "gulf_%d_%d" % [day, rng.randi() % 100000],
		"from_club_id": club.club_id,
		"from_club_name": club.club_name,
		"kind": "traspaso",
		"fee": int(value * rng.randf_range(GULF_FEE_MULT.x, GULF_FEE_MULT.y)),
		"wage": wage,
		"contract_years": rng.randi_range(2, 3),
		"role": "titular",
		"release_clause": int(value * 4.0),
		"window_day": next_window_day,
		"created_day": day,
		"gulf": true,
		"signing_bonus": int(wage * GULF_BONUS_OF_WAGE),
		"countered": true, # el sueldo ya es descomunal: no se negocia más
	}
	if deadline:
		_mark_deadline(o, day)
	return o

## ¿Toca oferta del Golfo esta semana?
static func should_gulf(player: PlayerData, world: Dictionary, season: Dictionary, day: int, rng: RandomNumberGenerator) -> bool:
	if not gulf_eligible(player, world):
		return false
	if not season.get("pending_transfer", {}).is_empty() or not PreContractEngine.signed(season).is_empty():
		return false
	if TransferOfferEngine.inbox(season).size() >= TransferOfferEngine.MAX_INBOX:
		return false
	var wk: int = CalendarUtils.week_index(day)
	if wk < int(season.get("gulf_offer_week", -999)) + GULF_COOLDOWN_WEEKS:
		return false
	var age_push: float = 1.0 + clampf(float(player.age - 29) * 0.2, 0.0, 1.0) # a partir de los 30 insisten más
	return rng.randf() < GULF_WEEKLY_CHANCE * age_push

static func note_gulf(season: Dictionary, day: int) -> void:
	season["gulf_offer_week"] = CalendarUtils.week_index(day)

## Al concretarse el fichaje (TransferOfferEngine.execute_pending): prima de
## fichaje y el precio deportivo del Golfo. Devuelve una línea para prensa o "".
static func apply_on_execute(player: PlayerData, pt: Dictionary) -> String:
	if not bool(pt.get("gulf", false)):
		return ""
	player.balance += int(pt.get("signing_bonus", 0))
	player.reputation = maxi(player.reputation - GULF_REP_COST, 0)
	return "Prima de fichaje de %s. La prensa deportiva te lo reprocha: -%d reputación." % [CurrencyFormat.format(int(pt.get("signing_bonus", 0))), GULF_REP_COST]

## ¿Se puede cerrar hoy este acuerdo aunque la ventana ya haya cerrado?
## (oferta del último día aceptada: se firma al pasar ese día).
static func closes_after_bell(pt: Dictionary, day: int) -> bool:
	return bool(pt.get("deadline", false)) and day <= int(pt.get("window_day", -10)) + 1
