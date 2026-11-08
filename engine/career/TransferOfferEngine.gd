extends RefCounted
class_name TransferOfferEngine

## Ofertas de OTROS clubes por el usuario, que pueden llegar en CUALQUIER
## momento de la temporada (fuera de la ventana de fichajes). El usuario
## acepta o rechaza; una oferta aceptada queda PENDIENTE y se ejecuta sola
## al abrir la ventana de fichajes más cercana. Puede ser traspaso o
## cesión (préstamo).
##
## Toda la matemática de sueldo/valor la reusa de ContractEngine/
## TransferMarketEngine — nunca una segunda fórmula (ver CLAUDE.md). Estado
## en el dict `season` (aditivo, sin cambio de esquema):
##   season["transfer_inbox"]      -> Array de ofertas sin responder
##   season["pending_transfer"]    -> la oferta aceptada que se ejecutará
##   season["transfer_offers_week"]-> semana de la última oferta generada

const WEEKLY_CHANCE := 0.06
const MAX_INBOX := 4
const REP_FLOOR := 40 # con menos reputación casi no llegan ofertas

## Cuántos partidos dura el empujón real de la promesa "titular" al fichar
## (ver execute_pending/apply_role_boost) y cuánto/hasta dónde empuja la
## chance de arrancar de CoachRelations.start_chance.
const TITULAR_PROMISE_MATCHES := 6
const TITULAR_PROMISE_BOOST := 0.30
const TITULAR_PROMISE_CAP := 0.85 # mismo techo que AgentEngine.LOBBY_CAP — nunca una garantía

static func _week(day: int) -> int:
	return CalendarUtils.week_index(day)

static func should_offer(player: PlayerData, day: int, season: Dictionary, rng: RandomNumberGenerator) -> bool:
	if player == null or player.club_id == "":
		return false
	if int(season.get("transfer_offers_week", -1)) == _week(day):
		return false
	var inbox: Array = season.get("transfer_inbox", [])
	if inbox.size() >= MAX_INBOX:
		return false
	if not season.get("pending_transfer", {}).is_empty():
		return false # ya aceptaste una, no llegan más hasta que se ejecute
	if not PreContractEngine.signed(season).is_empty():
		return false # ya firmaste un precontrato con otro club
	# Si PEDISTE salir y el club abrió la veda, las ofertas llegan mucho más
	# seguido durante unas semanas (TransferRequestEngine).
	var requested: bool = not TransferRequestEngine.active(season, day).is_empty()
	var rep_factor: float = clampf(float(player.reputation - REP_FLOOR) / 45.0, 0.05, 1.4)
	if requested:
		rep_factor = maxf(rep_factor, 0.9)
	var contract_factor: float = 1.4 if player.contract_years_remaining <= 1 else 1.0
	var base_chance: float = 0.55 if requested else WEEKLY_CHANCE
	return rng.randf() < base_chance * rep_factor * contract_factor

## Devuelve la oferta o {} si no se pudo armar. `next_window_day` = día en
## que abre la próxima ventana (se ejecuta ahí).
static func generate_offer(player: PlayerData, world: Dictionary, world_seed: int, day: int, next_window_day: int, rng: RandomNumberGenerator, season: Dictionary = {}) -> Dictionary:
	var by_league: Dictionary = world.get("clubs_by_league", {})
	var meta: Dictionary = world.get("club_meta_by_id", {})
	# REALISMO: un club te busca si estás EN SU RANGO de nivel — de un poco
	# por debajo (querés dar el salto) a bastante por encima (un grande que
	# te sube de categoría). A un canterano con margen lo miran clubes más
	# grandes (fichan por el potencial).
	var p_ov: int = player.overall
	var ceiling: int = 12 + int(round(maxf(0.0, float(player.potential - player.overall)) * 0.45))
	# No repitas los últimos pretendientes (Wilber: "casi siempre los mismos
	# equipos"). Guardamos los 6 últimos en season["recent_suitors"].
	var recent: Array = season.get("recent_suitors", []) if season is Dictionary else []
	var cands: Array = []
	for arr in by_league.values():
		for c in arr:
			if c.club_id == player.club_id or c.club_id in recent:
				continue
			var bo: int = int(meta.get(c.club_id, {}).get("base_overall", 55))
			if bo >= p_ov - 7 and bo <= p_ov + ceiling:
				cands.append({"club": c, "bo": bo})
	if cands.is_empty():
		# Nadie nuevo en rango: ampliamos ignorando el "recent" y el rango.
		for arr in by_league.values():
			for c in arr:
				if c.club_id == player.club_id:
					continue
				var bo2: int = int(meta.get(c.club_id, {}).get("base_overall", 55))
				if absi(bo2 - p_ov) <= 14:
					cands.append({"club": c, "bo": bo2})
	if cands.is_empty():
		return {}
	# Pick PONDERADO: más peso cuanto más cerca del "objetivo" (tu nivel +
	# un saltito), pero con harta cola — así NO sale siempre el mismo club.
	var target_bo: float = float(p_ov) + 3.0
	var total_w: float = 0.0
	for e in cands:
		e["w"] = 1.0 / (1.0 + absf(float(e["bo"]) - target_bo) * 0.22)
		total_w += e["w"]
	var pick: float = rng.randf() * total_w
	var suitor: ClubData = cands[cands.size() - 1]["club"]
	for e in cands:
		pick -= float(e["w"])
		if pick <= 0.0:
			suitor = e["club"]
			break

	# Los juveniles (≤21) reciben MUCHAS más ofertas de cesión — clubes
	# que los quieren a préstamo una temporada para que sumen minutos.
	var loan_chance: float = 0.55 if player.age <= 21 else 0.22
	var is_loan: bool = rng.randf() < loan_chance and player.contract_years_remaining >= 2
	var value: int = player.market_value
	if value <= 0:
		value = TransferMarketEngine.market_value(player.overall, player.potential, player.age)
	var fee: int = 0 if is_loan else int(value * rng.randf_range(0.85, 1.6))
	var base_wage: int = ContractEngine.renewal_wage(player.wage, player.coach_trust, 0.5, player.overall) if player.wage > 0 else maxi(value / 40, 20)
	# Bug de techo esquivado (auditoría, ronda 2): renewal_wage() ya
	# clampea base_wage, pero el *1.05-1.45 de acá podía volver a pasarse
	# hasta un 45% — mismo criterio que WageOfferEngine, que sí re-clampea
	# después de su propio multiplicador.
	var wage: int = mini(int(base_wage * rng.randf_range(1.05, 1.45)), ContractEngine.wage_ceiling(player.overall))
	var years: int = 1 if is_loan else rng.randi_range(2, 4)
	# Rol que te ofrecen según tu nivel vs el del club que ficha.
	var suitor_bo: int = int(meta.get(suitor.club_id, {}).get("base_overall", player.overall))
	var gap: int = suitor_bo - player.overall
	var role: String = "titular" if gap <= 1 else ("rotación" if gap <= 8 else "promesa")
	# Cláusula de rescisión: 2-3.5× tu valor de mercado (piso: 5× el sueldo
	# anual, un puñado de temporadas de sueldo — protege a un jugador con
	# valor de mercado muy bajo de quedar con una cláusula ridícula, sin
	# ser el número que manda). Bug real de la auditoría (ronda 6): con
	# 20× el sueldo, el "piso" terminaba siendo el valor real de la
	# cláusula en casi TODO el rango de overall jugable (hasta overall
	# ~95), dejando la fórmula de 2-3.5× el valor de mercado inservible en
	# la práctica — la cláusula nunca reflejaba el valor real del jugador.
	var release_clause: int = 0 if is_loan else maxi(int(value * rng.randf_range(2.0, 3.5)), wage * 5)

	# Anotá el pretendiente para no repetirlo pronto (6 últimos).
	if season is Dictionary:
		var rs: Array = [suitor.club_id]
		for cid in season.get("recent_suitors", []):
			if cid != suitor.club_id and rs.size() < 6:
				rs.append(cid)
		season["recent_suitors"] = rs

	return {
		"id": "offer_%d_%d" % [day, rng.randi() % 100000],
		"from_club_id": suitor.club_id,
		"from_club_name": suitor.club_name,
		"kind": "cesión" if is_loan else "traspaso",
		"fee": fee,
		"wage": wage,
		"contract_years": years,
		"role": role,
		"release_clause": release_clause,
		"window_day": next_window_day,
		"created_day": day,
	}

## --- CONTRAOFERTA con fecha límite (P5, 9-oct) ---------------------------
## Cada oferta vence a los OFFER_DAYS de llegar. Podés mandar UNA
## contraoferta (+COUNTER_RAISE de sueldo): el club responde a los
## COUNTER_DAYS — acepta, se queda a mitad de camino o se retira.
const OFFER_DAYS := 12
const COUNTER_DAYS := 2
const COUNTER_RAISE := 0.25

static func days_left(offer: Dictionary, day: int) -> int:
	return int(offer.get("created_day", day)) + OFFER_DAYS - day

static func can_counter(offer: Dictionary) -> bool:
	return not offer.has("counter") and not bool(offer.get("countered", false))

static func send_counter(season: Dictionary, offer_id: String, day: int) -> void:
	var inbox: Array = season.get("transfer_inbox", [])
	for o in inbox:
		if String(o.get("id", "")) == offer_id and can_counter(o):
			o["counter"] = {"wage": int(round(int(o.get("wage", 0)) * (1.0 + COUNTER_RAISE))), "respond_day": day + COUNTER_DAYS}
			o["created_day"] = maxi(int(o.get("created_day", day)), day + COUNTER_DAYS - OFFER_DAYS + 3)
	season["transfer_inbox"] = inbox

## Tick diario: vencen las ofertas viejas y se responden las contraofertas.
## Devuelve titulares [{headline, body, sentiment}] para la prensa.
static func daily_tick(season: Dictionary, player: PlayerData, day: int, rng: RandomNumberGenerator) -> Array:
	var news: Array = []
	var inbox: Array = season.get("transfer_inbox", [])
	var keep: Array = []
	for o in inbox:
		var name: String = String(o.get("from_club_name", "Un club"))
		if o.has("counter"):
			var c: Dictionary = o["counter"]
			if day >= int(c.get("respond_day", day)):
				var p_accept: float = clampf(0.35 + float(player.overall - 70) / 80.0, 0.2, 0.65)
				var r: float = rng.randf()
				o.erase("counter")
				o["countered"] = true
				if r < p_accept:
					o["wage"] = int(c["wage"])
					o["counter_result"] = "accepted"
					news.append({"headline": "%s acepta tu contraoferta" % name, "body": "Te pagan lo que pediste. La oferta sigue en tu buzón.", "sentiment": "POSITIVE"})
				elif r < p_accept + 0.35:
					o["wage"] = int(round((int(o.get("wage", 0)) + int(c["wage"])) * 0.5))
					o["counter_result"] = "halfway"
					news.append({"headline": "%s se queda a mitad de camino" % name, "body": "Mejoran el sueldo, pero no todo lo que pediste.", "sentiment": "NEUTRAL"})
				else:
					news.append({"headline": "%s se retira de la negociación" % name, "body": "Les pareció mucho lo que pediste y bajaron la oferta.", "sentiment": "CRITICAL"})
					continue
				o["created_day"] = day   # el plazo vuelve a correr tras la respuesta
			keep.append(o)
			continue
		if days_left(o, day) <= 0:
			if bool(o.get("deadline", false)):
				news.append({"headline": "Cierra el mercado: %s se queda con las ganas" % name, "body": "La oferta de última hora caducó sin respuesta.", "sentiment": "NEUTRAL"})
				continue
			news.append({"headline": "Vence la oferta de %s" % name, "body": "No respondiste a tiempo y la propuesta caducó.", "sentiment": "NEUTRAL"})
			continue
		keep.append(o)
	season["transfer_inbox"] = keep
	return news

## Actualiza los términos de una oferta del inbox tras negociarla.
static func update_offer_terms(season: Dictionary, offer_id: String, terms: Dictionary) -> void:
	var inbox: Array = season.get("transfer_inbox", [])
	for o in inbox:
		if String(o.get("id", "")) == offer_id:
			if terms.has("wage"): o["wage"] = int(terms["wage"])
			if terms.has("years"): o["contract_years"] = int(terms["years"])
			if terms.has("release_clause"): o["release_clause"] = int(terms["release_clause"])
			if terms.has("goal_bonus"): o["goal_bonus"] = int(terms["goal_bonus"])
			o["negotiated"] = true
			break
	season["transfer_inbox"] = inbox

## ¿El club actual BLOQUEA la venta ante esta oferta? (pedido de Wilber: si
## te llega una oferta y el club no te quiere vender, en vez de dejarte
## decidir a vos te ofrece una mejora de contrato). Más probable si estás
## muy por encima del nivel del club, el DT te valora y te queda contrato.
## Una oferta económica descomunal ablanda al club.
static func club_blocks_sale(player: PlayerData, club_base_overall: int, offer: Dictionary, rng: RandomNumberGenerator) -> bool:
	if player == null or player.contract_years_remaining < 1:
		return false
	if String(offer.get("kind", "")) == "cesión":
		return false  # una cesión no se bloquea así
	var importance: float = clampf((float(player.overall) - float(club_base_overall) + 6.0) / 18.0, 0.0, 1.0)
	var trust: float = clampf(float(player.coach_trust) / 100.0, 0.0, 1.0)
	var contract: float = clampf(float(player.contract_years_remaining) / 4.0, 0.0, 1.0)
	var p: float = 0.12 + importance * 0.48 + trust * 0.16 + contract * 0.14  # ~0.12 .. 0.90
	var fee: int = int(offer.get("fee", 0))
	var mv: int = maxi(player.market_value, 1)
	if fee > mv * 2.0:
		p *= 0.45  # dinero que no se puede rechazar
	elif fee > mv * 1.4:
		p *= 0.7
	return rng.randf() < clampf(p, 0.05, 0.92)

static func add_to_inbox(season: Dictionary, offer: Dictionary, day: int) -> void:
	var inbox: Array = season.get("transfer_inbox", [])
	inbox.append(offer)
	season["transfer_inbox"] = inbox
	season["transfer_offers_week"] = _week(day)

static func reject(season: Dictionary, offer_id: String) -> void:
	var inbox: Array = season.get("transfer_inbox", [])
	inbox = inbox.filter(func(o): return String(o.get("id", "")) != offer_id)
	season["transfer_inbox"] = inbox

## Acepta: la oferta pasa a pendiente y se vacía el resto del inbox (no
## podés tener dos aceptadas). Se ejecutará en la ventana.
static func accept(season: Dictionary, offer_id: String) -> Dictionary:
	var inbox: Array = season.get("transfer_inbox", [])
	var chosen: Dictionary = {}
	for o in inbox:
		if String(o.get("id", "")) == offer_id:
			chosen = o
			break
	if chosen.is_empty():
		return {}
	season["pending_transfer"] = chosen
	season["transfer_inbox"] = []
	return chosen

## En la ventana de fichajes: si hay una oferta aceptada, se concreta.
## Devuelve {ok, message}. Muta player (club_id, wage, contrato) y limpia.
static func execute_pending(player: PlayerData, season: Dictionary, world: Dictionary) -> Dictionary:
	var pt: Dictionary = season.get("pending_transfer", {})
	if pt.is_empty():
		return {"ok": false, "message": ""}
	var to_id: String = String(pt.get("from_club_id", ""))
	var to_name: String = String(pt.get("from_club_name", to_id))
	var is_loan: bool = String(pt.get("kind", "")) == "cesión"
	var extra: String = ""

	if to_id != "" and to_id != player.club_id:
		# Oferta del Golfo: prima de fichaje y su precio deportivo (DeadlineDayEngine).
		extra = DeadlineDayEngine.apply_on_execute(player, pt)
		if int(pt.get("fee", 0)) > 0:
			# El fee lo cobra el club vendedor, no el jugador — pero al
			# jugador le entra una prima de fichaje modesta.
			player.balance += maxi(int(pt["fee"] / 20), 0)
		# Cesión con club padre conocido (LoanEngine): guardamos a dónde
		# volver — el rollover de temporada devuelve al jugador.
		if is_loan and pt.has("parent_club_id"):
			var parent_club := WorldFactory.find_club(world, String(pt["parent_club_id"]))
			season["loan_return"] = {
				"parent_club_id": String(pt["parent_club_id"]),
				"parent_club_name": parent_club.club_name if parent_club != null else String(pt["parent_club_id"]),
				"parent_wage": int(pt.get("parent_wage", player.wage)),
				"parent_contract_years": int(pt.get("parent_contract_years", player.contract_years_remaining)),
			}
		# Memoria de carrera (v34): solo traspasos, no cesiones.
		var from_id: String = player.club_id
		if not is_loan:
			ImmersionEngine.note_club_left(player, world, to_id, int(season.get("start_year", 0)), "sold")
		player.club_id = to_id
		# Afición del club nuevo: arranca con su propio humor, no con el del viejo.
		var fan_news: Dictionary = FanBondEngine.on_joined(player, world, WorldTickEngine.world_seed, season, from_id)
		if not fan_news.is_empty():
			PressGenerator.append_to_feed(player, fan_news, WorldTickEngine.current_epoch_day)
		if not is_loan:
			# Derechos de imagen: se pactan con el club nuevo (los del Golfo dan más).
			ImageRightsEngine.on_new_club(player, ImageRightsEngine.GULF_SHARE if bool(pt.get("gulf", false)) else -1)
		player.wage = int(pt.get("wage", player.wage))
		player.contract_years_remaining = int(pt.get("contract_years", 2))
		player.club_seniority = 0
		# El club nuevo llega con una idea de tu ROL (generate_offer arriba
		# ya calcula "titular"/"rotación"/"promesa" según el hueco con su
		# nivel) — antes eso era SOLO una etiqueta cosmética en la oferta,
		# sin ningún efecto real en si jugabas o no (bug real reportado por
		# Wilber: "firmé para ser titular... y estoy de suplente"). Ahora
		# la confianza inicial con el DT sale de ahí (en vez de un 55 fijo
		# siempre pase lo que pase), y si prometieron titular se suma un
		# empujón real — pero temporal y nunca garantizado, ver
		# apply_role_boost — para los primeros partidos ahí.
		var role: String = String(pt.get("role", "rotación"))
		match role:
			"titular": player.coach_trust = 78
			"rotación": player.coach_trust = 55
			_: player.coach_trust = 42
		if role == "titular":
			player.active_effects["role_titular_matches"] = TITULAR_PROMISE_MATCHES
		player.market_value = TransferMarketEngine.market_value(player.overall, player.potential, player.age)

	season.erase("pending_transfer")
	season["transfer_inbox"] = []
	var verb: String = "Cedido a" if is_loan else "Fichaste por"
	return {"ok": true, "message": "%s %s. Nueva etapa." % [verb, to_name], "extra": extra}

## Aplica (y consume 1 de) el empujón de "te fiché para ser titular" sobre
## la chance base de CoachRelations.start_chance, mientras dure la promesa
## (player.active_effects["role_titular_matches"], armado en
## execute_pending). Sigue sin ser garantía — MatchTeam nunca elige la XI
## SOLO por favor — es un empujón real y notorio en tus primeros partidos
## ahí, ya no cosmético como antes. Llamado desde MatchLauncher.prepare(),
## el único lugar donde de verdad se decide titular/banco.
static func apply_role_boost(player: PlayerData, base_chance: float) -> float:
	if player == null:
		return base_chance
	var left: int = int(player.active_effects.get("role_titular_matches", 0))
	if left <= 0:
		return base_chance
	left -= 1
	if left <= 0:
		player.active_effects.erase("role_titular_matches")
	else:
		player.active_effects["role_titular_matches"] = left
	return clampf(base_chance + TITULAR_PROMISE_BOOST, 0.0, TITULAR_PROMISE_CAP)

static func inbox(season: Dictionary) -> Array:
	return season.get("transfer_inbox", [])

static func pending(season: Dictionary) -> Dictionary:
	return season.get("pending_transfer", {})
