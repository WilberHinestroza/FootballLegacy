extends RefCounted
class_name AcademyEngine

## Empezar en la cantera: con 15-17 años eliges la cantera de un club (las
## academias reclutan talento, así que llaman clubes algo mejores que si
## fueras directo a un primer equipo) y cobras una beca. Mientras estés ahí:
##  - Cada semana juegas un partido JUVENIL (se simula aquí: nota, goles,
##    asistencias, XP y desarrollo de atributos).
##  - El primer equipo juega sin ti salvo que el DT te CONVOQUE (según tu
##    media frente a la del club y tu forma en el juvenil).
##  - Si destacas, el club te SUBE al primer equipo a mitad de temporada con
##    tu primer contrato profesional. A los 18, revisión: o subes, o te dejan
##    libre y vas al mercado.
##
## Estado (sin cambio de esquema): player.active_effects["academy"] =
##   {state: "pending"|"youth"|"promoted"|"released", club_id, club_name,
##    club_strength, league_rep, since, matches, goals, assists, rating_sum,
##    callups, recent: [{day, rating, goals, assists, score}]}

const KEY := "academy"
const MAX_START_AGE := 17
const BECA_WAGE := 20                # €20K al año
const CONTRACT_YEARS := 4
const START_TRUST := 35
const OFFER_RATING_BONUS := 1.5      # las academias apuntan más alto
const YOUTH_GAP := 18                # nivel del juvenil = fuerza del club - esto
const PROMO_GAP := 8                 # subes a mitad de temporada con media >= fuerza - 8…
const PROMO_MIN_MATCHES := 6         # …tras al menos estos partidos juveniles…
const PROMO_MIN_AVG := 6.8           # …con esta nota media
const RELEASE_AGE := 18
const KEEP_GAP := 14                 # a los 18 te quedan si media >= fuerza - 14
const PRO_YEARS := 3
const PRO_TRUST := 50
const YOUTH_WEEKDAY := 5             # día de la semana (epoch % 7) del juvenil
const RECENT_MAX := 5
const GOAL_P := {"ST": 0.42, "MF": 0.18, "DF": 0.05, "GK": 0.0}
const ASSIST_P := {"ST": 0.20, "MF": 0.26, "DF": 0.08, "GK": 0.01}

static func data(player: PlayerData) -> Dictionary:
	var d = player.active_effects.get(KEY, {})
	return d if d is Dictionary else {}

static func is_pending(player: PlayerData) -> bool:
	return String(data(player).get("state", "")) == "pending"

static func in_academy(player: PlayerData) -> bool:
	return player != null and String(data(player).get("state", "")) == "youth" \
		and String(data(player).get("club_id", "")) == player.club_id

static func mark_pending(player: PlayerData) -> void:
	player.active_effects[KEY] = {"state": "pending"}

static func avg_rating(player: PlayerData) -> float:
	var d: Dictionary = data(player)
	return float(d.get("rating_sum", 0.0)) / float(maxi(int(d.get("matches", 0)), 1))

## Ofertas de cantera: mismas que el primer equipo (CareerSetup) pero
## apuntando más alto, con rol "cantera" y beca.
static func offers(player: PlayerData, trial_rating: float, world: Dictionary) -> Array:
	var out: Array = CareerSetup.generate_offers(player, clampf(trial_rating + OFFER_RATING_BONUS, 1.0, 10.0), world)
	for o in out:
		o["role"] = "cantera"
		o["wage"] = BECA_WAGE
		o["wage_hint"] = "beca"
		o["academy"] = true
	return out

## Firmas por la cantera elegida (llamar con player.club_id ya puesto).
static func enroll(player: PlayerData, offer: Dictionary, today: int) -> void:
	player.wage = BECA_WAGE
	player.contract_years_remaining = CONTRACT_YEARS
	player.coach_trust = START_TRUST
	player.active_effects[KEY] = {
		"state": "youth", "club_id": String(offer.get("club_id", player.club_id)),
		"club_name": String(offer.get("club_name", "")), "club_strength": int(offer.get("club_strength", 60)),
		"league_rep": int(offer.get("reputation", 60)), "since": today,
		"matches": 0, "goals": 0, "assists": 0, "rating_sum": 0.0, "callups": 0, "recent": [],
	}

static func youth_level(player: PlayerData) -> int:
	return int(data(player).get("club_strength", 60)) - YOUTH_GAP

# --------------------------------------------------------------------------
#  Partido juvenil semanal
# --------------------------------------------------------------------------

## Simula el partido juvenil de esta semana y lo anota. Devuelve
## {rating, goals, assists, score, won, xp}. Aplica XP y desarrollo.
static func play_youth_match(player: PlayerData, today: int, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = data(player)
	var gap: float = float(player.overall - youth_level(player))
	var rating: float = clampf(6.2 + gap * 0.07 + rng.randfn(0.0, 0.7), 3.5, 9.8)
	var pos: String = player.position if GOAL_P.has(player.position) else "MF"
	var boost: float = clampf(0.6 + (rating - 5.0) / 5.0, 0.3, 1.6)
	var goals := 0
	var assists := 0
	for i in 3:
		if rng.randf() < float(GOAL_P[pos]) * boost / 2.0:
			goals += 1
		if rng.randf() < float(ASSIST_P[pos]) * boost / 2.0:
			assists += 1
	rating = clampf(rating + 0.4 * goals + 0.25 * assists, 3.5, 10.0)
	# Resultado del equipo: más fácil de ganar cuanto mejor juegas.
	var us: int = rng.randi_range(0, 2) + goals + (1 if rating >= 7.5 else 0)
	var them: int = rng.randi_range(0, 3 if rating < 6.0 else 2)
	rating = snappedf(rating, 0.1)
	d["matches"] = int(d.get("matches", 0)) + 1
	d["goals"] = int(d.get("goals", 0)) + goals
	d["assists"] = int(d.get("assists", 0)) + assists
	d["rating_sum"] = float(d.get("rating_sum", 0.0)) + rating
	var recent: Array = d.get("recent", [])
	recent.append({"day": today, "rating": rating, "goals": goals, "assists": assists, "score": "%d-%d" % [us, them]})
	while recent.size() > RECENT_MAX:
		recent.pop_front()
	d["recent"] = recent
	player.active_effects[KEY] = d
	# Mismo XP y desarrollo que un partido de verdad (a la mitad: es el juvenil).
	var gains: Dictionary = PlayerDevelopment.match_xp_gains(player, rating, goals, assists)
	for k in gains:
		gains[k] = float(gains[k]) * 0.5
	PlayerDevelopment.grant_attribute_xp(player, gains)
	var xp: int = int(ProgressionEngine.match_xp(rating, goals, assists, us > them, true, false) / 2)
	ProgressionEngine.add_xp(player, xp)
	return {"rating": rating, "goals": goals, "assists": assists, "score": "%d-%d" % [us, them], "won": us > them, "xp": xp}

## Noticia del juvenil si hubo algo que contar, o {}.
static func youth_press(player: PlayerData, r: Dictionary) -> Dictionary:
	var g: int = int(r.get("goals", 0))
	var club: String = String(data(player).get("club_name", "su club"))
	if g >= 3:
		return {"headline": "Hat-trick en el juvenil de %s" % club, "body": "%s firma tres goles (%s) y ya se habla de él en el primer equipo." % [player.player_name, String(r.score)], "source": "CANTERA", "sentiment": "POSITIVE"}
	if float(r.get("rating", 0)) >= 8.6:
		return {"headline": "Exhibición en la cantera de %s" % club, "body": "Nota de %.1f para %s en el partido juvenil (%s)." % [float(r.rating), player.player_name, String(r.score)], "source": "CANTERA", "sentiment": "POSITIVE"}
	return {}

# --------------------------------------------------------------------------
#  Primer equipo: convocatorias y ascenso
# --------------------------------------------------------------------------

## Probabilidad de que el DT te suba a un partido del primer equipo.
static func callup_chance(player: PlayerData) -> float:
	var d: Dictionary = data(player)
	if int(d.get("matches", 0)) < 2:
		return 0.03
	var gap: float = float(player.overall - (int(d.get("club_strength", 60)) - 16))
	return clampf(0.03 + gap * 0.025 + maxf(avg_rating(player) - 6.5, 0.0) * 0.12, 0.0, 0.55)

## ¿Te convocan para este partido? Determinista por fecha y club.
static func called_up(player: PlayerData, fixture: Dictionary, world_seed: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("acad_call:%d:%s" % [int(fixture.get("epoch_day", 0)), player.club_id]) ^ world_seed
	return rng.randf() < callup_chance(player)

## ¿Este partido del primer equipo lo ves desde fuera? (MatchLauncher)
static func sits_out(player: PlayerData, fixture: Dictionary, world_seed: int) -> bool:
	if not in_academy(player) or String(fixture.get("competition", "")) == "friendly":
		return false
	if String(fixture.get("home_club_id", "")) != player.club_id and String(fixture.get("away_club_id", "")) != player.club_id:
		return false
	return not called_up(player, fixture, world_seed)

## Partido del primer equipo jugado estando convocado desde la cantera.
static func note_callup_played(player: PlayerData) -> void:
	if not in_academy(player):
		return
	var d: Dictionary = data(player)
	d["callups"] = int(d.get("callups", 0)) + 1
	player.active_effects[KEY] = d

## Qué te falta para subir (para la UI): lista de [texto, cumplido].
static func promotion_checklist(player: PlayerData) -> Array:
	var d: Dictionary = data(player)
	var need: int = int(d.get("club_strength", 60)) - PROMO_GAP
	return [
		["Media %d de %d" % [player.overall, need], player.overall >= need],
		["%d de %d partidos juveniles" % [mini(int(d.get("matches", 0)), PROMO_MIN_MATCHES), PROMO_MIN_MATCHES], int(d.get("matches", 0)) >= PROMO_MIN_MATCHES],
		["Nota media %.1f de %.1f" % [avg_rating(player), PROMO_MIN_AVG], avg_rating(player) >= PROMO_MIN_AVG],
	]

static func promotion_ready(player: PlayerData) -> bool:
	if not in_academy(player):
		return false
	for c in promotion_checklist(player):
		if not bool(c[1]):
			return false
	return true

## Subes al primer equipo: primer contrato profesional. Devuelve la noticia.
static func promote(player: PlayerData, today: int) -> Dictionary:
	var d: Dictionary = data(player)
	d["state"] = "promoted"
	d["promoted_day"] = today
	player.active_effects[KEY] = d
	player.contract_years_remaining = PRO_YEARS
	player.wage = maxi(mini(ContractEngine.starting_wage(int(d.get("club_strength", 60)), int(d.get("league_rep", 60))),
		ContractEngine.wage_ceiling(player.overall)), BECA_WAGE)
	player.coach_trust = maxi(player.coach_trust, PRO_TRUST)
	player.reputation = clampi(player.reputation + 2, 0, 100)
	player.mood = clampi(player.mood + 10, 0, 100)
	return {"headline": "%s sube al primer equipo de %s" % [player.player_name, String(d.get("club_name", "su club"))],
		"body": "De la cantera a la élite: firma su primer contrato profesional por %d temporadas (%s al año)." % [PRO_YEARS, CurrencyFormat.format(player.wage)],
		"source": "CANTERA", "sentiment": "POSITIVE"}

## Cierre de temporada (WorldTickEngine._begin_season_rollover, con la edad
## ya sumada). Devuelve {result: "promoted"|"released"|"stay"|"", news}.
static func season_review(player: PlayerData, today: int) -> Dictionary:
	if not in_academy(player):
		return {"result": ""}
	if promotion_ready(player):
		return {"result": "promoted", "news": promote(player, today)}
	if player.age < RELEASE_AGE:
		player.contract_years_remaining = maxi(player.contract_years_remaining, 1)
		return {"result": "stay"}
	var d: Dictionary = data(player)
	if player.overall >= int(d.get("club_strength", 60)) - KEEP_GAP:
		return {"result": "promoted", "news": promote(player, today)}
	d["state"] = "released"
	player.active_effects[KEY] = d
	player.contract_years_remaining = 0
	return {"result": "released", "news": {
		"headline": "%s no sigue en %s" % [player.player_name, String(d.get("club_name", "su club"))],
		"body": "A los %d años el club no le ofrece contrato profesional. Queda libre: toca buscarse la vida en el mercado." % player.age,
		"source": "CANTERA", "sentiment": "NEGATIVE"}}
