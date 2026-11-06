extends RefCounted
class_name CareerSetup

## Lógica del arranque de carrera: el partido de prueba tras el test de
## personalidad y la generación de las 5 ofertas de club según cómo salga
## esa prueba.
##
## Aprendizaje de FL: nada de balance disperso. La nota de la prueba la
## calcula MatchRatingCalculator (eventos reales, no overall). Aquí solo
## se traduce esa nota a "calidad de oferta".

const TRIAL_SQUAD_SIZE := 16
const OFFERS_COUNT := 5
const MAX_OFFERS_PER_LEAGUE := 2

## Dos equipos neutrales para la prueba de scouting. El usuario va en el
## equipo local ("Prueba A"). No es eliminatoria.
static func build_trial_teams(player: PlayerData) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("trial:" + player.player_name)

	var club_a := ClubData.new()
	club_a.club_id = "trial_a"
	club_a.club_name = "Prueba A"
	var club_b := ClubData.new()
	club_b.club_id = "trial_b"
	club_b.club_name = "Prueba B"

	# Nivel de la prueba: juvenil/scouting, deliberadamente medio-bajo para
	# que el rendimiento del usuario destaque en un sentido u otro.
	var squad_a := _trial_squad(rng, 54)
	var squad_b := _trial_squad(rng, 55)

	# La prueba existe para EVALUARTE — no tendría sentido que te quedaras
	# en el banco. Titular garantizado (chance 1.0), a diferencia de un
	# partido de liga normal donde compites por el puesto de verdad.
	var team_a := MatchTeam.from_club(club_a, squad_a, player, 1.0)
	var team_b := MatchTeam.from_club(club_b, squad_b, null)
	return {"home": team_a, "away": team_b}

static func _trial_squad(rng: RandomNumberGenerator, base: int) -> Array[PlayerData]:
	var slots := ["GK", "DF", "DF", "DF", "DF", "MF", "MF", "MF", "MF", "ST", "ST"]
	while slots.size() < TRIAL_SQUAD_SIZE:
		slots.append(["DF", "MF", "ST"][rng.randi() % 3])
	var squad: Array[PlayerData] = []
	for i in range(slots.size()):
		var p := PlayerData.new()
		p.position = slots[i]
		p.detailed_position = Positions.default_detailed_for_broad(slots[i])
		p.player_name = WorldFactory._make_person_name(rng)
		p.country = Countries.ALL[rng.randi() % Countries.ALL.size()]
		var ov: int = clampi(base + rng.randi_range(-7, 7), 35, 75)
		p.overall = ov
		p.potential = clampi(ov + rng.randi_range(0, 15), ov, 90)
		p.age = rng.randi_range(16, 21)
		p.speed = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.stamina = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.strength = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.control = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.passing = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.shooting = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.dribbling = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.decision_making = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.composure = clampi(ov + rng.randi_range(-8, 8), 25, 90)
		p.ensure_potential_floor()
		squad.append(p)
	return squad

## Traduce la confianza del entrenador (0-100) a una "nota" equivalente
## (1-10) para reutilizar generate_offers() en un fichaje de MITAD de
## carrera (mercado de fichajes, Fase 8b), donde no hay una prueba real
## que jugar. Misma idea que con la prueba: una sola fuente traduce
## rendimiento -> calidad de oferta, nunca dispersa por pantallas.
static func pseudo_rating_from_trust(trust: int) -> float:
	return clampf(4.0 + (float(trust) / 100.0) * 5.0, 1.0, 10.0)

## Genera OFFERS_COUNT ofertas de club en función de la nota de la prueba
## (1-10). world es el dict devuelto por WorldFactory.build().
##
## Reglas pedidas:
##  - Si el país de origen del jugador tiene liga, al menos una oferta es
##    de esa liga.
##  - Al menos una oferta internacional (otro país).
##  - Mejor prueba -> ligas y clubes de más reputación.
static func generate_offers(player: PlayerData, trial_rating: float, world: Dictionary) -> Array:
	# Se tira UNA vez al crear la carrera y las ofertas quedan guardadas —
	# no hace falta determinismo. Semilla REALMENTE aleatoria: antes era
	# hash(nombre) ^ nota, así que dos carreras parecidas daban los MISMOS
	# clubes (Wilber: "me volvió a salir Bucaramanga").
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# 0..1: perilla de calidad. Nota 4 o menos -> 0; nota 9 o más -> 1.
	var quality: float = clampf((trial_rating - 4.0) / 5.0, 0.0, 1.0)
	# Objetivo de reputación de LIGA y de nivel de CLUB por separado — antes
	# solo pesaba por reputación de LIGA, así que "acertar" LaLiga podía
	# tocarte cualquier club de LaLiga al azar, del Real Madrid al Alavés,
	# con el mismo peso (Wilber jugando: "nunca llego a un gran club").
	# Ahora un club grande DENTRO de una liga grande queda más priorizado
	# que uno chico de la misma liga. Techo de target_rep subido de 90 a
	# 96 — antes ni con nota perfecta se apuntaba de lleno a las ligas top
	# de verdad (Premier League=96, LaLiga=95 en este mundo).
	var target_rep: float = lerpf(42.0, 96.0, quality)
	var target_club_level: float = lerpf(40.0, 92.0, quality)
	var player_level: float = player.overall + (trial_rating - MatchRatingCalculator.BASE_RATING) * 3.0

	var leagues: Array = world.get("leagues", [])
	var clubs_by_league: Dictionary = world.get("clubs_by_league", {})
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})

	# Candidatos con un PESO (más alto cuanto más cerca de la reputación de
	# SU liga Y del nivel de SU club) y se sortean por MUESTREO PONDERADO
	# al azar — no "los 5 más cercanos". Antes, aun con ruido, un mundo fijo
	# (p.ej. importado) devolvía casi siempre los mismos 5 clubes (Wilber:
	# "creé 3 partidas y las negociaciones son siempre las mismas"). Ahora
	# dos carreras en el MISMO mundo dan ofertas distintas.
	var candidates: Array = []
	for league in leagues:
		for club in clubs_by_league.get(league.league_id, []):
			var meta: Dictionary = meta_by_id.get(club.club_id, {})
			var rep_distance: float = absf(float(league.reputation) - target_rep)
			var club_level: float = float(meta.get("base_overall", league.reputation))
			var club_distance: float = absf(club_level - target_club_level)
			var combined_distance: float = rep_distance * 0.5 + club_distance * 0.5
			# ventana ancha: a 25 de distancia combinada el peso ya es ~0.3;
			# a 50, ~0.14 — siguen entrando outsiders de vez en cuando.
			var weight: float = 1.0 / (1.0 + pow(combined_distance / 14.0, 1.6))
			candidates.append({
				"club": club,
				"league": league,
				"meta": meta,
				"weight": weight,
				"score": combined_distance,   # solo para "_raw_score" (desempates internos)
			})
	_weighted_shuffle(candidates, rng)

	var home_league: LeagueData = WorldFactory.find_league_for_country(world, player.country)
	var picked: Array = []
	var per_league: Dictionary = {}
	var used_clubs: Dictionary = {}

	# 1) Garantizar una oferta del país de origen si existe esa liga.
	if home_league != null:
		for c in candidates:
			if c["league"].league_id == home_league.league_id:
				_take_offer(c, picked, per_league, used_clubs)
				break

	# 2) Rellenar con los mejores candidatos, máx. MAX_OFFERS_PER_LEAGUE por liga.
	for c in candidates:
		if picked.size() >= OFFERS_COUNT:
			break
		if used_clubs.has(c["club"].club_id):
			continue
		if per_league.get(c["league"].league_id, 0) >= MAX_OFFERS_PER_LEAGUE:
			continue
		_take_offer(c, picked, per_league, used_clubs)

	# 3) Asegurar al menos una internacional (país != país del jugador).
	var has_international := picked.any(func(o): return o["country"] != player.country)
	if not has_international and picked.size() > 0:
		for c in candidates:
			if used_clubs.has(c["club"].club_id):
				continue
			if c["league"].country == player.country:
				continue
			# Sustituye la peor oferta nacional actual.
			picked.sort_custom(func(a, b): return a["_raw_score"] > b["_raw_score"])
			var dropped: Dictionary = picked.pop_front()
			used_clubs.erase(dropped["club_id"])
			per_league[dropped["league_id"]] = per_league.get(dropped["league_id"], 1) - 1
			_take_offer(c, picked, per_league, used_clubs)
			break

	# 4) Relleno de emergencia si el mundo tuviera pocas ligas.
	for c in candidates:
		if picked.size() >= OFFERS_COUNT:
			break
		if used_clubs.has(c["club"].club_id):
			continue
		_take_offer(c, picked, per_league, used_clubs)

	for o in picked:
		o["role"] = _role_for(player_level, o["club_strength"])
		o["wage_hint"] = _wage_hint(o["reputation"])
		# Bug real de la auditoría: acá se mostraba el sueldo "de mercado" del
		# CLUB (fuerza/reputación), sin clampear al techo realista del propio
		# jugador (ContractEngine.wage_ceiling) — Offers.gd sí aplicaba el
		# clamp al FIRMAR, así que el número que el jugador veía y "aceptaba"
		# en la hoja de contrato podía ser varias veces mayor al que
		# terminaba cobrando de verdad, sin ningún aviso. Mismo criterio que
		# ya se usa en renovación/negociación: clampear ACÁ, donde se arma el
		# número que se muestra.
		o["wage"] = mini(ContractEngine.starting_wage(o["club_strength"], o["reputation"]), ContractEngine.wage_ceiling(player.overall))
		o["is_home_country"] = o["country"] == player.country
	return picked

static func _take_offer(c: Dictionary, picked: Array, per_league: Dictionary, used_clubs: Dictionary) -> void:
	var club: ClubData = c["club"]
	var league: LeagueData = c["league"]
	var meta: Dictionary = c["meta"]
	var squad := WorldFactory.make_squad(meta)
	picked.append({
		"club_id": club.club_id,
		"club_name": club.club_name,
		"league_id": league.league_id,
		"league_name": league.league_name,
		"country": league.country,
		"reputation": league.reputation,
		"club_strength": WorldFactory.squad_strength(squad),
		"_raw_score": c["score"],
	})
	per_league[league.league_id] = per_league.get(league.league_id, 0) + 1
	used_clubs[club.club_id] = true

## Permutación PONDERADA al azar (Efraimidis-Spirakis): items con más
## `weight` tienden a quedar primeros, pero con azar real — dos tiradas
## dan órdenes distintos. Reordena `arr` in-place.
static func _weighted_shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for c in arr:
		var w: float = maxf(float(c.get("weight", 0.001)), 0.0001)
		c["_k"] = pow(rng.randf(), 1.0 / w)
	arr.sort_custom(func(a, b): return float(a["_k"]) > float(b["_k"]))

static func _role_for(player_level: float, club_strength: int) -> String:
	var gap: float = club_strength - player_level
	if gap <= 2.0:
		return "titular"
	if gap <= 10.0:
		return "rotación"
	return "promesa"

static func _wage_hint(reputation: int) -> String:
	if reputation >= 88:
		return "élite"
	if reputation >= 75:
		return "alto"
	if reputation >= 62:
		return "bueno"
	return "modesto"
