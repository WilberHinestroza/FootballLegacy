extends RefCounted
class_name TransferMarketEngine

## Mercado de fichajes IA-a-IA — pedido explícito de Wilber: presupuesto
## real por club, valor de mercado real por jugador, niveles de fichaje
## (potente/bueno/normal/suave) y pujas cruzadas para los más grandes.
## Reemplaza la versión anterior (un "strength_delta" al azar sin
## relación con nada + titulares 100% cosméticos): ahora el fichaje
## EXISTE de verdad — ver WorldFactory.make_squad_with_transfers(), que
## saca al jugador del plantel de origen y lo pone en el de destino.
##
## Mundo vivo: TODO esto es una función pura de (world_seed,
## season_start_epoch_day) — se recalcula desde cero cada vez que se
## pide (cacheado en memoria nada más para no repetir el trabajo dentro
## de la misma consulta, ver `season_transfers_cached`), nunca se
## persiste. El presupuesto de un club no es un número que se "gasta y
## se guarda" — es una fórmula determinista que ya tiene en cuenta cuánto
## puede haber gastado esa temporada.

# --- Niveles de fichaje, por overall del jugador ---
const TIER_STRONG_MIN := 85   # "potente"
const TIER_GOOD_MIN := 75     # "bueno"
const TIER_NORMAL_MIN := 65   # "normal" — debajo de esto, "suave"

# --- Cuántos fichajes de cada nivel arma el mundo por temporada ---
const TRANSFERS_STRONG := 4
const TRANSFERS_GOOD := 12
const TRANSFERS_NORMAL := 26
const TRANSFERS_SOFT := 40

const BIDDERS_FOR_STRONG := 3 # pujas cruzadas — solo los fichajes "potentes" arman guerra de ofertas
const _ATTEMPTS_PER_TRANSFER := 8

## Unidad monetaria de TODO este archivo: MILES DE EURO — un fee de 4700
## es "4.7M €", uno de 267 es "267K €" (mismo criterio que ya usaba la
## prensa de fichajes antes de esta reescritura). CurrencyFormat.gd
## convierte a USD para mostrar si el usuario eligió esa moneda en
## Ajustes — la unidad interna siempre es esta.
const BUDGET_SCALE := 10.0

## Presupuesto de fichajes de un club para ESTA temporada — determinista,
## función de su propia fuerza y la reputación de su liga (los grandes de
## las ligas top manejan presupuestos de cientos de millones; los chicos
## de ligas menores, unos pocos).
static func budget_for_club(base_overall: int, league_reputation: int, world_seed: int, club_id: String, season_start_epoch_day: int) -> int:
	var scale: float = pow(maxf(float(base_overall - 40), 1.0), 2.3) * (float(league_reputation) / 70.0) * BUDGET_SCALE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("budget:%d:%s" % [season_start_epoch_day, club_id]) ^ world_seed
	return maxi(int(scale * rng.randf_range(0.8, 1.2)), 200)

## Valor de mercado de un jugador, en miles de euro — fórmula única
## (antes vivía solo dentro de la prensa de fichajes como `_estimate_fee`,
## ahora es la fuente de verdad también para PlayerData.market_value, ver
## WorldFactory.make_squad). Un potencial bien por encima del overall
## actual (una promesa) vale más de lo que su nivel de hoy sugiere.
static func market_value(overall: int, potential: int, age: int) -> int:
	var age_factor: float = 1.0 if age <= 28 else maxf(0.3, 1.0 - float(age - 28) * 0.08)
	var growth_factor: float = 1.0 + maxf(0.0, float(potential - overall)) * 0.03
	var base: float = pow(maxf(float(overall - 40), 1.0), 2.6) * age_factor * growth_factor
	# Prima de PRIME/ÉLITE: de 80 para arriba el valor se dispara — sin esto
	# la curva `pow(ov-40, 2.6)` se quedaba MUY por debajo de la escala del
	# mundo importado (un 85 real vale €50-80M, un Balón de Oro €120-170M).
	# Por debajo de 80 no cambia nada.
	if overall >= 80:
		base *= 1.0 + pow(float(overall - 79), 1.6) * 0.05
	return maxi(int(base), 20)

static func tier_for_overall(overall: int) -> String:
	if overall >= TIER_STRONG_MIN:
		return "potente"
	if overall >= TIER_GOOD_MIN:
		return "bueno"
	if overall >= TIER_NORMAL_MIN:
		return "normal"
	return "suave"

static func _tier_ceiling(tier_name: String) -> int:
	match tier_name:
		"potente":
			return 999
		"bueno":
			return TIER_STRONG_MIN
		"normal":
			return TIER_GOOD_MIN
		_:
			return TIER_NORMAL_MIN

static var _cache_key: String = ""
static var _cache: Array = []

## Sal por CARRERA (SaveManager.load_market_salt) que WorldTickEngine.
## load_runtime() empuja acá al entrar a la carrera. Se mezcla en la
## semilla del mercado para que dos carreras nuevas sobre el MISMO mundo
## importado (world_seed fijo == -1) NO den los mismos fichajes (reporte
## de Wilber: "siempre salen los mismos movimientos a los mismos equipos").
## 0 = save legacy (v23 o anterior) → mercado idéntico al de antes de v24.
static var _salt: int = 0

## Desde qué temporada (día de inicio) hay BOMBAZOS (SaveManager v35). Lo
## empuja WorldTickEngine.load_runtime(). 0 = siempre.
static var _v2_from_day: int = 0

static func set_v2_from(day: int) -> void:
	if day != _v2_from_day:
		_v2_from_day = day
		_cache_key = ""

static func set_salt(salt_value: int) -> void:
	if salt_value != _salt:
		_salt = salt_value
		_cache_key = ""   # el mercado cacheado ya no vale

## Punto de entrada normal para todo lo demás (WorldFactory,
## WorldTickEngine): cachea en memoria para no repetir el trabajo de
## armar ~80 fichajes (que a su vez llaman make_squad varias veces cada
## uno) en cada consulta dentro del mismo (world_seed, season_start, salt).
static func season_transfers_cached(world: Dictionary, world_seed: int, season_start_epoch_day: int) -> Array:
	var key: String = "%d:%d:%d:%d" % [world_seed, season_start_epoch_day, _salt, _v2_from_day]
	if _cache_key != key:
		_cache = generate_season_transfers(world, world_seed ^ _salt, season_start_epoch_day)
		_cache_key = key
	return _cache

## Lista completa de fichajes IA-a-IA de la temporada — pura, determinista.
## Cada entrada: {origin_club_id, origin_index, destination_club_id, fee,
## tier, player_name, position, overall, bidders: Array[String] (otros
## clubes que pujaron y perdieron, solo tiene datos para "potente")}.
## `origin_index`: posición del jugador dentro del plantel BASE de
## origen (WorldFactory.make_squad sin fichajes aplicados) — así
## make_squad_with_transfers() puede reconstruir exactamente a ESE
## jugador sin tener que darle una identidad propia y persistida.
## Cache de planteles por club para NO reconstruir cada uno decenas de
## veces dentro de generate_season_transfers.
static func _cached_squad(club_id: String, meta_by_id: Dictionary, cache: Dictionary) -> Array:
	if not cache.has(club_id):
		cache[club_id] = WorldFactory.make_squad(meta_by_id.get(club_id, {}))
	return cache[club_id]

## Qué tan bien le viene ESTE jugador a ESTE club: necesidad de su puesto,
## encaje con la filosofía/estilo del DT, y proyección (club ambicioso ↔
## joven con recorrido / club "ganar ya" ↔ no gasta en veteranos). Pedido
## de Wilber: "la IA cuando contrata debe tener sentido por filosofía,
## necesidad de posición, dinero y proyección del jugador". Multiplicador
## sobre la puja base (~0.5 a ~3).
static func _bidder_fit(bidder_id: String, player: PlayerData, clubs_by_id: Dictionary, coaches: Dictionary, squad_cache: Dictionary, meta_by_id: Dictionary) -> float:
	var fit: float = 1.0
	var club: ClubData = clubs_by_id.get(bidder_id, null)
	var coach: CoachData = coaches.get(bidder_id, null)

	# --- Necesidad de posición ---
	var bsquad: Array = _cached_squad(bidder_id, meta_by_id, squad_cache)
	var same_detail: int = 0
	var same_broad: int = 0
	for sp in bsquad:
		if sp.detailed_position == player.detailed_position:
			same_detail += 1
		if sp.position == player.position:
			same_broad += 1
	if same_detail <= 1:
		fit *= 1.7   # casi no tiene a nadie de ese puesto exacto
	elif same_detail == 2:
		fit *= 1.15
	if same_broad <= 2:
		fit *= 1.3   # la línea entera está fina

	# --- Filosofía / estilo del DT ---
	if coach != null:
		var prof: float
		match String(coach.play_style):
			"Posesión": prof = (player.passing + player.control) * 0.5
			"Presión alta": prof = (player.speed + player.stamina) * 0.5
			"Directo": prof = (player.shooting + player.strength) * 0.5
			"Contraataque": prof = (player.speed + player.dribbling) * 0.5
			_: prof = float(player.overall)
		fit *= lerpf(0.75, 1.4, clampf((prof - 45.0) / 45.0, 0.0, 1.0))

	# --- Proyección ---
	var amb: int = int(club.league_ambition) if club != null else 50
	var upside: int = player.potential - player.overall
	if player.age <= 23 and upside >= 8:
		fit *= 1.0 + (float(amb) / 100.0) * 0.6   # apuesta al proyecto
	elif player.age >= 30 and amb >= 65:
		fit *= 0.8                                # quieren ganar YA
	if player.age >= 32:
		fit *= 0.85

	return clampf(fit, 0.35, 3.2)

static func generate_season_transfers(world: Dictionary, world_seed: int, season_start_epoch_day: int) -> Array:
	var club_meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	var club_ids: Array = club_meta_by_id.keys()
	if club_ids.size() < 2:
		return []

	var leagues_by_id: Dictionary = {}
	for lg in world.get("leagues", []):
		leagues_by_id[int(lg.league_id)] = lg
	var clubs_by_id: Dictionary = {}
	for arr in world.get("clubs_by_league", {}).values():
		for c in arr:
			clubs_by_id[c.club_id] = c
	var coaches: Dictionary = world.get("coach_by_club_id", {})
	var squad_cache: Dictionary = {}

	var remaining_budget: Dictionary = {}
	for club_id in club_ids:
		var meta: Dictionary = club_meta_by_id[club_id]
		var league_id: int = int(meta.get("league_id", -1))
		var league_rep: int = int(leagues_by_id[league_id].reputation) if leagues_by_id.has(league_id) else 55
		remaining_budget[club_id] = budget_for_club(int(meta.get("base_overall", 55)), league_rep, world_seed, club_id, season_start_epoch_day)

	var tiers: Array = [
		{"name": "potente", "min_overall": TIER_STRONG_MIN, "count": TRANSFERS_STRONG, "bidders": BIDDERS_FOR_STRONG},
		{"name": "bueno", "min_overall": TIER_GOOD_MIN, "count": TRANSFERS_GOOD, "bidders": 1},
		{"name": "normal", "min_overall": TIER_NORMAL_MIN, "count": TRANSFERS_NORMAL, "bidders": 1},
		{"name": "suave", "min_overall": 0, "count": TRANSFERS_SOFT, "bidders": 1},
	]

	var used_players: Dictionary = {} # "club_id:index" -> true — un jugador no se vende dos veces la misma ventana
	var transfers: Array = []

	for tier_spec in tiers:
		var tier_name: String = String(tier_spec["name"])
		var min_ov: int = int(tier_spec["min_overall"])
		var max_ov: int = _tier_ceiling(tier_name)
		for i in range(int(tier_spec["count"])):
			var pick_rng := RandomNumberGenerator.new()
			pick_rng.seed = hash("transfer:%s:%d" % [tier_name, i]) ^ world_seed ^ season_start_epoch_day

			var origin_id: String = ""
			var origin_index: int = -1
			var player: PlayerData = null
			for attempt in range(_ATTEMPTS_PER_TRANSFER):
				var candidate_club: String = club_ids[pick_rng.randi() % club_ids.size()]
				var squad: Array = _cached_squad(candidate_club, club_meta_by_id, squad_cache)
				var candidates_idx: Array = []
				for idx in range(squad.size()):
					if used_players.has("%s:%d" % [candidate_club, idx]):
						continue
					if squad[idx].overall >= min_ov and squad[idx].overall < max_ov:
						candidates_idx.append(idx)
				if not candidates_idx.is_empty():
					origin_id = candidate_club
					origin_index = candidates_idx[pick_rng.randi() % candidates_idx.size()]
					player = squad[origin_index]
					break
			if player == null:
				continue

			var value: int = market_value(player.overall, player.potential, player.age)
			# REALISMO: quién puede fichar a este jugador según su nivel.
			# Normal: el club comprador está AL NIVEL o por ENCIMA del jugador
			# (un grande se lleva a la estrella de uno chico, no al revés).
			# Excepción: veteranos (≥31) pueden bajar de categoría ("última
			# etapa"); cuanto más viejo, más margen hacia abajo.
			var vet_drop: int = 0
			if player.age >= 31:
				vet_drop = 6 + (player.age - 31) * 3
			var min_dest_bo: int = player.overall - 4 - vet_drop
			var max_dest_bo: int = player.overall + 14  # ni un gigante ficha muy por debajo suyo... salvo joyas: lo cubre el pick por tier

			var bidder_ids: Array = []
			var pool_attempts: int = 0
			while bidder_ids.size() < int(tier_spec["bidders"]) and pool_attempts < 40:
				pool_attempts += 1
				var bidder: String = club_ids[pick_rng.randi() % club_ids.size()]
				if bidder == origin_id or bidder_ids.has(bidder):
					continue
				var b_bo: int = int(club_meta_by_id.get(bidder, {}).get("base_overall", 55))
				if b_bo < min_dest_bo or b_bo > max_dest_bo:
					continue
				if float(remaining_budget.get(bidder, 0)) < float(value) * 0.6:
					continue
				bidder_ids.append(bidder)
			# Si nadie del rango encaja, relajamos SOLO el presupuesto (no el
			# nivel) — antes de descartar el fichaje del todo.
			if bidder_ids.is_empty():
				for _r in range(30):
					var b2: String = club_ids[pick_rng.randi() % club_ids.size()]
					if b2 == origin_id:
						continue
					var bo2: int = int(club_meta_by_id.get(b2, {}).get("base_overall", 55))
					if bo2 >= min_dest_bo and bo2 <= max_dest_bo:
						bidder_ids.append(b2)
						break
			if bidder_ids.is_empty():
				continue

			# Gana el que MÁS lo quiere = puja (dinero) × encaje (posición +
			# filosofía + proyección). El `fee` sale de la puja cruda.
			var winner: String = ""
			var winner_offer: float = 0.0
			var winner_score: float = -1.0
			for b in range(bidder_ids.size()):
				var candidate: String = String(bidder_ids[b])
				var offer: float = float(remaining_budget.get(candidate, 0)) * pick_rng.randf_range(0.15, 0.35)
				var score: float = offer * _bidder_fit(candidate, player, clubs_by_id, coaches, squad_cache, club_meta_by_id)
				if score > winner_score:
					winner_score = score
					winner_offer = offer
					winner = candidate

			var fee: int = maxi(int(maxf(winner_offer, float(value) * 0.7)), value)
			fee = mini(fee, int(remaining_budget.get(winner, 0)))
			if fee <= 0:
				continue

			remaining_budget[winner] = int(remaining_budget[winner]) - fee
			remaining_budget[origin_id] = int(remaining_budget.get(origin_id, 0)) + fee
			used_players["%s:%d" % [origin_id, origin_index]] = true

			var others: Array = bidder_ids.filter(func(b): return String(b) != winner)
			# ~15% de los movimientos son cesiones/préstamos (fee simbólico).
			# Roll DERIVADO (no consume pick_rng, así no cambia el resto del
			# stream ni las fuerzas de club ya calculadas para saves en curso).
			var is_loan: bool = absi(hash("loan:%s:%d:%d" % [origin_id, origin_index, world_seed])) % 100 < 15
			var out_fee: int = int(maxf(float(fee) * 0.05, 1.0)) if is_loan else fee
			# Día real en que se resuelve — pedido de Wilber: "en el mercado
			# deben ir pasando fichajes cada día, no que al primer día pase
			# de una todo". Otro roll DERIVADO (mismo criterio que is_loan
			# arriba: no cambia QUÉ fichajes pasan, solo CUÁNDO se revelan
			# en la pantalla de Mercado — ver Transfers.gd._render_world).
			# ~70% cae en la ventana de verano, el resto en la de invierno;
			# los "potente" (nivel bombazo) se inclinan a los últimos 3 días
			# de su ventana, como el día del cierre real del mercado.
			var window_roll: int = absi(hash("window:%s:%d:%d" % [origin_id, origin_index, world_seed])) % 100
			var w_start: int = season_start_epoch_day if window_roll < 70 \
				else season_start_epoch_day + SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET
			var w_len: int = SeasonCalendar.TRANSFER_WINDOW_DAYS - 1
			var day_roll: int = absi(hash("day:%s:%d:%d" % [origin_id, origin_index, world_seed])) % 1000
			var day_offset: int = (w_len - day_roll % 3) if tier_name == "potente" \
				else int(float(day_roll) / 1000.0 * float(w_len))
			transfers.append({
				"origin_club_id": origin_id, "origin_index": origin_index, "destination_club_id": winner,
				"fee": out_fee, "tier": tier_name, "player_name": player.player_name,
				"position": player.position, "overall": player.overall, "bidders": others,
				# 11-oct: datos para los filtros del Mercado (solo se muestran; no
				# cambian qué fichajes pasan).
				"age": player.age, "value": value,
				"kind": "cesión" if is_loan else "compra", "day": w_start + day_offset,
			})

	if season_start_epoch_day >= _v2_from_day:
		transfers.append_array(_bombazos(world_seed, season_start_epoch_day, club_meta_by_id, squad_cache, used_players, remaining_budget))
	return transfers

# --- BOMBAZOS (v35) --------------------------------------------------------
## Por qué no había: el nivel "potente" elige un CLUB al azar (8 intentos) y
## busca ahí un jugador de 85+. Casi ningún club tiene uno, así que casi
## nunca salía: medido el 11-oct, 77 fichajes por temporada y la media más
## alta que se movía era 78. Acá se hace al revés: se arma la lista de las
## FIGURAS de los clubes más fuertes y cada temporada unas pocas cambian de
## equipo, a otro grande, por una cifra récord y cerca del cierre.
const BOMBAZO_TOP_CLUBS := 36        # los clubes más fuertes del mundo
const BOMBAZO_STAR_MARGIN := 3       # "figura" = hasta 3 puntos del mejor de su club...
const BOMBAZO_MIN_OVERALL := 80      # ...y al menos esta media
const BOMBAZOS_MIN := 2
const BOMBAZOS_MAX := 4
const BOMBAZO_FEE_MIN := 1.15        # se paga por encima del valor de mercado
const BOMBAZO_FEE_MAX := 1.60

static func _bombazos(world_seed: int, season_start_epoch_day: int, meta_by_id: Dictionary, squad_cache: Dictionary, used_players: Dictionary, remaining_budget: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = meta_by_id.keys()
	ids.sort_custom(func(a, b):
		var ba: int = int(meta_by_id[a].get("base_overall", 0))
		var bb: int = int(meta_by_id[b].get("base_overall", 0))
		return ba > bb if ba != bb else String(a) < String(b))
	var top: Array = ids.slice(0, mini(BOMBAZO_TOP_CLUBS, ids.size()))
	if top.size() < 4:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bombazos:%d:%d" % [season_start_epoch_day, world_seed])
	# Las figuras: lo mejor de cada club grande.
	var stars: Array = []
	for cid in top:
		var squad: Array = _cached_squad(cid, meta_by_id, squad_cache)
		var best: int = 0
		for p in squad:
			best = maxi(best, int(p.overall))
		for idx in range(squad.size()):
			var pl: PlayerData = squad[idx]
			if pl.position == "GK" or used_players.has("%s:%d" % [cid, idx]):
				continue
			if pl.overall >= best - BOMBAZO_STAR_MARGIN and pl.overall >= BOMBAZO_MIN_OVERALL and pl.age <= 31:
				stars.append([cid, idx])
	if stars.is_empty():
		return out
	var want: int = rng.randi_range(BOMBAZOS_MIN, BOMBAZOS_MAX)
	var sellers: Dictionary = {}
	var buyers: Dictionary = {}
	var guard: int = 0
	while out.size() < want and guard < 60:
		guard += 1
		var pick: Array = stars[rng.randi() % stars.size()]
		var origin_id: String = String(pick[0])
		var origin_index: int = int(pick[1])
		var key: String = "%s:%d" % [origin_id, origin_index]
		# Un club no vende ni compra dos figuras el mismo año.
		if used_players.has(key) or sellers.has(origin_id) or buyers.has(origin_id):
			continue
		var player: PlayerData = _cached_squad(origin_id, meta_by_id, squad_cache)[origin_index]
		var origin_bo: int = int(meta_by_id[origin_id].get("base_overall", 55))
		# Destino: otro grande, de su nivel o mejor (nadie así baja de escalón).
		var dests: Array = []
		for cid2 in top:
			if cid2 == origin_id or buyers.has(cid2) or sellers.has(cid2):
				continue
			if int(meta_by_id[cid2].get("base_overall", 55)) >= origin_bo - 2:
				dests.append(cid2)
		if dests.is_empty():
			continue
		var dest: String = String(dests[rng.randi() % dests.size()])
		var value: int = market_value(player.overall, player.potential, player.age)
		var fee: int = int(float(value) * rng.randf_range(BOMBAZO_FEE_MIN, BOMBAZO_FEE_MAX))
		used_players[key] = true
		sellers[origin_id] = true
		buyers[dest] = true
		remaining_budget[dest] = int(remaining_budget.get(dest, 0)) - fee
		remaining_budget[origin_id] = int(remaining_budget.get(origin_id, 0)) + fee
		# Otros dos grandes que pujaron y perdieron.
		var others: Array = []
		for cid3 in dests:
			if cid3 != dest and others.size() < 2 and rng.randf() < 0.5:
				others.append(cid3)
		# La mayoría en verano, sobre el cierre; alguno en invierno.
		var winter: bool = rng.randf() < 0.22
		var w_start: int = season_start_epoch_day + (SeasonCalendar.MID_SEASON_TRANSFER_WINDOW_OFFSET if winter else 0)
		var w_len: int = SeasonCalendar.TRANSFER_WINDOW_DAYS - 1
		var day: int = w_start + (w_len - rng.randi() % 4 if rng.randf() < 0.6 else rng.randi() % maxi(w_len, 1))
		out.append({
			"origin_club_id": origin_id, "origin_index": origin_index, "destination_club_id": dest,
			"fee": fee, "tier": "potente", "player_name": player.player_name,
			"position": player.position, "overall": player.overall, "bidders": others,
			"age": player.age, "value": value, "bombazo": true,
			"kind": "compra", "day": day,
		})
	return out

## Efecto NETO de todos los fichajes de la temporada sobre la fuerza de
## cada club — un club que vendió a su figura se debilita, uno que compró
## fuerte se refuerza, en proporción al overall del jugador que
## entra/sale sobre un plantel de referencia de 18 (mismo criterio que
## WorldImporter._avg_overall). Reemplaza el viejo roll al azar
## desconectado de la realidad: ahora el número sale DIRECTO de a quién
## se fichó de verdad.
static func net_strength_deltas(transfers: Array) -> Dictionary:
	var raw: Dictionary = {}
	for t in transfers:
		var impact: float = float(t["overall"]) / 18.0
		var dest: String = String(t["destination_club_id"])
		var orig: String = String(t["origin_club_id"])
		raw[dest] = float(raw.get(dest, 0.0)) + impact
		raw[orig] = float(raw.get(orig, 0.0)) - impact
	var result: Dictionary = {}
	for k in raw:
		result[k] = int(round(clampf(float(raw[k]), -8.0, 8.0)))
	return result
