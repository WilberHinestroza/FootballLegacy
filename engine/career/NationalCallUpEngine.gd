extends RefCounted
class_name NationalCallUpEngine

## Convocatoria a la selección nacional (Fase 2 de selecciones) — POR
## MÉRITO, nunca una relación persistente tipo CoachRelations.coach_trust
## de club (pedido explícito de Wilber en el scoping: "media/reputación/
## forma reciente deciden, podés quedar afuera si rendís mal"). Se
## RECALCULA entero cada ventana FIFA a partir del estado actual del
## jugador — PlayerData.national_team_status es el RESULTADO narrativo de
## este cálculo, nunca un acumulador (no hay "amistad" con un DT nacional
## que se pueda ir ganando con el tiempo).
##
## Balance centralizado acá, un solo lugar — nunca dupliques esta fórmula
## en WorldTickEngine ni en ninguna pantalla.

## Cuántos lugares tiene cada línea (GK/DF/MF/ST) en un plantel de 23 —
## reparto realista de un plantel de selección real.
const LINE_SLOTS := {"GK": 3, "DF": 8, "MF": 7, "ST": 5}
## Por debajo de este nivel, una convocatoria absoluta no es realista,
## incluso si el país tiene pocos jugadores disponibles.
const ABSOLUTE_MIN_OVERALL := 60

## Ranking (1-based) del usuario dentro de su PAÍS, en SU LÍNEA AMPLIA
## (GK/DF/MF/ST — nunca la posición detallada: hay pocos "DFC puros" pero
## muchos DF en general). Mérito objetivo por overall.
static func rank_in_position(user_player: PlayerData, country_pool: Array[PlayerData]) -> int:
	var same_line: Array[PlayerData] = country_pool.filter(func(p): return p.position == user_player.position)
	same_line.sort_custom(func(a, b): return a.overall > b.overall)
	for i in range(same_line.size()):
		if same_line[i] == user_player:
			return i + 1
	return same_line.size() + 1

## Probabilidad de convocatoria esta ventana. `rank`: 1-based en tu línea
## (ver rank_in_position). `recent_form`: 0.0-1.0, forma reciente
## normalizada (el llamador la arma desde season["user_rating_sum"]/
## ["user_rating_games"] — esta clase no lee `season`, nunca depende de
## autoloads). Dentro del cupo de tu línea → convocatoria SEGURA (sos
## claramente de los mejores del país en tu puesto); en la "burbuja" →
## curva suave que premia reputación/forma, nunca 0 duro salvo estar MUY
## lejos del corte.
##
## BUG REAL arreglado (Wilber: "me convocaron a la selección Colombia con
## una media de 55, eso no es normal"): "dentro del cupo de tu línea" era
## 100% relativo al `country_pool` de ESE llamado — que para países con
## pocos jugadores REALES de esa nacionalidad se completa con relleno
## SINTÉTICO (NationalTeamFactory._finish_squad) cuya fuerza sale de
## `country_base_reputation()`, no de nada absoluto. En un país con pool
## flojo, un overall mediocre podía rankear 1º en su línea igual y
## convocarse 100% GARANTIZADO sin que el nivel absoluto importara nada.
## Ahora, aunque rankees dentro del cupo, tu propio nivel tiene que
## superar `TransferMarketEngine.TIER_NORMAL_MIN` (65 — el piso de
## "nivel aceptable" que ya usa el resto del juego, ver tier_for_overall)
## para la convocatoria SEGURA; por debajo de eso, por más que seas el
## mejor disponible, pasa a la curva de probabilidad de siempre (nunca
## 0 duro, pero ya no automática).
static func call_up_probability(rank: int, line: String, reputation: int, recent_form: float, overall: int) -> float:
	if overall <= ABSOLUTE_MIN_OVERALL:
		return 0.0
	var slots: int = int(LINE_SLOTS.get(line, 6))
	var over: int = maxi(rank - slots, 0)
	if rank <= slots and overall >= TransferMarketEngine.TIER_NORMAL_MIN:
		return 1.0
	if rank <= slots:
		# Rankea dentro del cupo pero el nivel absoluto no da la talla —
		# lo tratamos como si estuviera recién pasado el corte, en vez de
		# 0 (sigue siendo, literalmente, el mejor disponible).
		over = 1
	var base: float = clampf(1.0 - float(over) / float(slots), 0.0, 1.0)
	var rep_factor: float = clampf(float(reputation) / 100.0, 0.0, 1.0)
	var form_factor: float = clampf(recent_form, 0.0, 1.0)
	# El ranking por sí solo no puede convertir a un juvenil de nivel bajo en
	# internacional: hasta 65 el mérito absoluto reduce mucho la probabilidad.
	var quality := clampf(float(overall - ABSOLUTE_MIN_OVERALL) / 10.0, 0.0, 1.0)
	return clampf(pow(base, 1.5) * (0.5 + 0.3 * rep_factor + 0.2 * form_factor) * pow(quality, 2.0), 0.0, 0.95)

## Resuelve la convocatoria de esta ventana FIFA. `rng` determinista
## (sembrado por el llamador, mismo criterio "mundo vivo" que el resto del
## juego — nunca el RNG global). Devuelve {"called_up": bool, "status":
## String, "probability": float, "rank": int} — `status` ∈ "captain" |
## "regular" | "fringe" | "left_out" (ver PlayerData.national_team_status).
static func resolve(user_player: PlayerData, country_pool: Array[PlayerData], recent_form: float, rng: RandomNumberGenerator) -> Dictionary:
	var rank: int = rank_in_position(user_player, country_pool)
	var probability: float = call_up_probability(rank, user_player.position, user_player.reputation, recent_form, user_player.overall)
	var called_up: bool = rng.randf() < probability
	var slots: int = int(LINE_SLOTS.get(user_player.position, 6))
	var status: String
	if not called_up:
		status = "left_out"
	elif rank == 1 and user_player.reputation >= 80:
		status = "captain"
	elif rank <= slots:
		status = "regular"
	else:
		status = "fringe"
	return {"called_up": called_up, "status": status, "probability": probability, "rank": rank}

## Forma reciente normalizada 0.0-1.0 a partir del acumulador de rating de
## la temporada que YA existe (WorldTickEngine.season["user_rating_sum"]/
## ["user_rating_games"], el mismo que usa el resumen de "Rendimiento" en
## Premios anuales) — nunca un stat nuevo. Rating típico 3-10 (ver
## MatchRatingCalculator); 6.5 (aprobado) mapea a ~0.5.
static func recent_form_from_rating(rating_sum: float, rating_games: int) -> float:
	if rating_games <= 0:
		return 0.5 # sin partidos esta temporada: neutral, ni castiga ni premia
	var avg: float = rating_sum / float(rating_games)
	return clampf((avg - 4.0) / 6.0, 0.0, 1.0)
