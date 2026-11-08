extends RefCounted
class_name FanBondEngine

## Afición por club: cada hinchada de tu carrera tiene su propio CARIÑO
## contigo (0-100) que dura toda la carrera. Lo suben los partidos, los goles,
## las asistencias, las temporadas y los títulos con su camiseta, y también
## el humor del día a día (season["fan_sentiment"]). Cómo te vas lo baja:
## libre, vendido, con precontrato… o directo a su clásico rival (traidor).
##
## Lo usan: la tribuna cuando vuelves de visitante (ImmersionEngine),
## la bienvenida si regresas a un ex club, el humor de base de la afición
## de tu club (al que decae season["fan_sentiment"]) y el legado.
##
## Estado (sin cambio de esquema, diccionario ya existente):
##   player.active_effects["club_fans"] = {club_id: {name, love, matches, goals,
##       assists, titles, seasons, left, left_season}}
##   player.active_effects["club_fans_titles_seen"]  = títulos ya acreditados
##   player.active_effects["club_fans_season_club"]  = {start_year: club_id}

const KEY := "club_fans"
const KEY_TITLES := "club_fans_titles_seen"
const KEY_SEASON_CLUB := "club_fans_season_club"

const START_LOVE := 40.0
const FROM_RIVAL_LOVE := 20.0        # llegas desde su clásico rival
const SENIORITY_LOVE := 6.0          # partidas viejas: por temporada en el club
const MATCH_LOVE := 0.35
const GOAL_LOVE := 1.0
const ASSIST_LOVE := 0.5
const MOOD_SHARE := 0.2              # parte del humor del partido que queda
const TITLE_LOVE := 8.0
const SEASON_LOVE := 3.0
const SEASON_MIN_MATCHES := 8
const RETURN_LOVE := 8.0             # vuelves a un club que te quiere
const RIVAL_CAP := 10.0
const LEAVE_DELTA := {"free": -6.0, "sold": -12.0, "precontract": -18.0}

## (mínimo, nombre) de mayor a menor.
const TIERS := [
	[85, "Ídolo"], [65, "Querido"], [45, "Respetado"], [30, "Indiferente"], [15, "Resentido"], [0, "Enemigo"],
]
const IDOL_LOVE := 85
const RECEPTION_IDOL := 70
const RECEPTION_HOSTILE := 15

# --------------------------------------------------------------------------
#  Lectura
# --------------------------------------------------------------------------

static func all(player: PlayerData) -> Dictionary:
	var d = player.active_effects.get(KEY, {})
	return d if d is Dictionary else {}

static func entry(player: PlayerData, club_id: String) -> Dictionary:
	var e = all(player).get(club_id, {})
	return e if e is Dictionary else {}

static func love(player: PlayerData, club_id: String) -> int:
	return int(round(float(entry(player, club_id).get("love", START_LOVE))))

static func tier_name(love_v: int, left: String = "") -> String:
	if left == "rival":
		return "Traidor"
	for t in TIERS:
		if love_v >= int(t[0]):
			return String(t[1])
	return "Enemigo"

## Humor de base de la afición de tu club: hacia aquí decae fan_sentiment.
## Con cariño 40 queda en 55 (el neutro de siempre); un ídolo, ~70.
static func baseline(love_v: float) -> int:
	return clampi(int(round(45.0 + love_v * 0.25)), 40, 75)

## Clubes en orden de cariño (el tuyo primero), para la UI.
static func ranked(player: PlayerData) -> Array:
	var out: Array = []
	var d: Dictionary = all(player)
	for cid in d:
		var row: Dictionary = (d[cid] as Dictionary).duplicate()
		row["club_id"] = cid
		row["current"] = cid == player.club_id
		out.append(row)
	out.sort_custom(func(a, b):
		if bool(a.current) != bool(b.current):
			return bool(a.current)
		return float(a.get("love", 0)) > float(b.get("love", 0)))
	return out

# --------------------------------------------------------------------------
#  Arranque (partidas anteriores a esta función)
# --------------------------------------------------------------------------

## Crea las entradas que falten: tu club actual y tus ex clubes (v34), con un
## cariño estimado por los años que estuviste. Idempotente.
static func bootstrap(player: PlayerData, world: Dictionary, world_seed: int) -> void:
	if player == null:
		return
	var d: Dictionary = all(player)
	var changed := false
	for fc in player.former_clubs:
		var cid: String = String(fc.get("club_id", ""))
		if cid == "" or d.has(cid) or cid == player.club_id:
			continue
		var lv: float = START_LOVE + SENIORITY_LOVE * float(fc.get("seniority", 0)) + float(LEAVE_DELTA["free"])
		var left := "free"
		var rival: String = RivalryEngine.club_rival_for(world, cid, world_seed) if not world.is_empty() else ""
		if rival != "" and String(fc.get("to_club_id", "")) == rival:
			left = "rival"
			lv = minf(lv, RIVAL_CAP)
		var e: Dictionary = _new_entry(String(fc.get("name", cid)), lv)
		e["left"] = left
		e["left_season"] = int(fc.get("left_season", 0))
		e["seasons"] = int(fc.get("seniority", 0))
		d[cid] = e
		changed = true
	if player.club_id != "" and not d.has(player.club_id):
		var club: ClubData = WorldFactory.find_club(world, player.club_id) if not world.is_empty() else null
		var e2: Dictionary = _new_entry(club.club_name if club != null else player.club_id,
			START_LOVE + SENIORITY_LOVE * float(player.club_seniority))
		e2["seasons"] = player.club_seniority
		d[player.club_id] = e2
		changed = true
	if changed:
		player.active_effects[KEY] = d
	if not player.active_effects.has(KEY_TITLES):
		# Lo ganado antes de existir esto no se reparte a ciegas.
		player.active_effects[KEY_TITLES] = player.career_titles.size()

static func _new_entry(club_name: String, lv: float) -> Dictionary:
	return {"name": club_name, "love": clampf(lv, 0.0, 100.0), "matches": 0, "goals": 0,
		"assists": 0, "titles": 0, "seasons": 0, "left": "", "left_season": 0}

# --------------------------------------------------------------------------
#  Eventos
# --------------------------------------------------------------------------

## Partido oficial con tu club. `fan_delta` = lo que se movió el humor de la
## afición por el partido (MatchSummary). Actualiza season["fan_baseline"].
static func on_match(player: PlayerData, world: Dictionary, world_seed: int, season: Dictionary,
		goals: int, assists: int, fan_delta: int) -> void:
	if player == null or player.club_id == "":
		return
	bootstrap(player, world, world_seed)
	var d: Dictionary = all(player)
	var e: Dictionary = d[player.club_id]
	e["matches"] = int(e.get("matches", 0)) + 1
	e["goals"] = int(e.get("goals", 0)) + goals
	e["assists"] = int(e.get("assists", 0)) + assists
	var add: float = MATCH_LOVE + GOAL_LOVE * float(goals) + ASSIST_LOVE * float(assists) + MOOD_SHARE * float(fan_delta)
	e["love"] = clampf(float(e.get("love", START_LOVE)) + add, 0.0, 100.0)
	d[player.club_id] = e
	player.active_effects[KEY] = d
	if not season.is_empty():
		var sc: Dictionary = _season_clubs(player)
		sc[str(int(season.get("start_year", 0)))] = player.club_id
		player.active_effects[KEY_SEASON_CLUB] = sc
		season["fan_baseline"] = baseline(float(e["love"]))
	sync_titles(player)

static func _season_clubs(player: PlayerData) -> Dictionary:
	var sc = player.active_effects.get(KEY_SEASON_CLUB, {})
	return sc if sc is Dictionary else {}

## ¿Es un título de club (no de selección ni individual) ganado?
static func _is_club_title(t: Dictionary) -> bool:
	var id: String = String(t.get("id", ""))
	var kind: String = String(t.get("kind", ""))
	if kind == "individual" or id == "world_cup" or id.begins_with("natcup_"):
		return false
	return int(t.get("metal", 1)) == 1

## Acredita los títulos de club nuevos al club con el que jugaste esa
## temporada (aunque ya te hayas ido: los de liga se apuntan en el rollover).
## Devuelve cuántos acreditó.
static func sync_titles(player: PlayerData) -> int:
	var n: int = player.career_titles.size()
	var seen: int = int(player.active_effects.get(KEY_TITLES, n))
	if seen >= n:
		player.active_effects[KEY_TITLES] = n
		return 0
	var d: Dictionary = all(player)
	var sc: Dictionary = _season_clubs(player)
	var credited := 0
	for i in range(seen, n):
		var t: Dictionary = player.career_titles[i]
		if not _is_club_title(t):
			continue
		var cid: String = String(sc.get(str(int(t.get("season", 0))), player.club_id))
		if not d.has(cid):
			continue
		d[cid]["titles"] = int(d[cid].get("titles", 0)) + 1
		d[cid]["love"] = clampf(float(d[cid].get("love", START_LOVE)) + TITLE_LOVE, 0.0, 100.0)
		credited += 1
	player.active_effects[KEY] = d
	player.active_effects[KEY_TITLES] = n
	return credited

## Cierre de temporada: títulos pendientes y la temporada cumplida suma al
## club con el que la jugaste (si jugaste lo suficiente).
static func on_season_closed(player: PlayerData, ended_start_year: int, matches_played: int) -> void:
	if player == null:
		return
	sync_titles(player)
	var cid: String = String(_season_clubs(player).get(str(ended_start_year), ""))
	var d: Dictionary = all(player)
	if cid == "" or not d.has(cid):
		return
	d[cid]["seasons"] = int(d[cid].get("seasons", 0)) + 1
	if matches_played >= SEASON_MIN_MATCHES:
		d[cid]["love"] = clampf(float(d[cid].get("love", START_LOVE)) + SEASON_LOVE, 0.0, 100.0)
	player.active_effects[KEY] = d

## Te vas del club actual (traspaso o fin de contrato; NO cesión). Llamar
## ANTES de cambiar player.club_id. how = "free" | "sold" | "precontract".
## Devuelve una noticia para la prensa o {}.
static func on_left(player: PlayerData, world: Dictionary, world_seed: int, to_club_id: String, how: String, season_year: int) -> Dictionary:
	if player == null or player.club_id == "" or player.club_id == to_club_id:
		return {}
	bootstrap(player, world, world_seed)
	sync_titles(player)
	var d: Dictionary = all(player)
	var e: Dictionary = d[player.club_id]
	var before: float = float(e.get("love", START_LOVE))
	var rival: String = RivalryEngine.club_rival_for(world, player.club_id, world_seed)
	var lv: float
	var left: String = how if LEAVE_DELTA.has(how) else "free"
	if rival != "" and to_club_id == rival:
		left = "rival"
		lv = minf(before, RIVAL_CAP)
	else:
		# Un ídolo que se va pierde menos: la gente entiende.
		var k: float = 0.5 if before >= float(IDOL_LOVE) else 1.0
		lv = before + float(LEAVE_DELTA[left]) * k
	e["love"] = clampf(lv, 0.0, 100.0)
	e["left"] = left
	e["left_season"] = season_year
	d[player.club_id] = e
	player.active_effects[KEY] = d
	var club_name: String = String(e.get("name", ""))
	if left == "rival":
		return {"headline": "La afición de %s no perdona: «traidor»" % club_name,
			"body": "Irse directo al clásico rival te deja marcado en %s para siempre." % club_name,
			"source": "AFICIÓN", "sentiment": "NEGATIVE"}
	if before >= float(IDOL_LOVE):
		return {"headline": "%s despide a su ídolo" % club_name,
			"body": "Pancartas de agradecimiento y lágrimas en la grada: allí siempre serás de la casa.",
			"source": "AFICIÓN", "sentiment": "POSITIVE"}
	return {}

## Llegas a un club (fichaje o vuelta de un ex club). Llamar DESPUÉS de
## cambiar player.club_id; `from_club_id` es el club del que vienes. Ajusta
## el humor de la afición de la temporada en curso. Devuelve noticia o {}.
static func on_joined(player: PlayerData, world: Dictionary, world_seed: int, season: Dictionary, from_club_id: String) -> Dictionary:
	if player == null or player.club_id == "":
		return {}
	var d: Dictionary = all(player)
	var cid: String = player.club_id
	var news: Dictionary = {}
	var club: ClubData = WorldFactory.find_club(world, cid)
	var club_name: String = club.club_name if club != null else cid
	if d.has(cid):
		var e: Dictionary = d[cid]
		var lv: float = float(e.get("love", START_LOVE))
		if String(e.get("left", "")) == "rival" or lv < float(RECEPTION_HOSTILE):
			news = {"headline": "Vuelve a %s y la grada recela" % club_name,
				"body": "No todos olvidan cómo se fue. Tendrá que ganarse a la afición otra vez.",
				"source": "AFICIÓN", "sentiment": "NEGATIVE"}
		elif lv >= 50.0 and String(e.get("left", "")) != "":
			lv += RETURN_LOVE
			news = {"headline": "Vuelve a casa: %s lo recibe con los brazos abiertos" % club_name,
				"body": "La afición no olvidó lo que dio con esta camiseta.",
				"source": "AFICIÓN", "sentiment": "POSITIVE"}
		e["love"] = clampf(lv, 0.0, 100.0)
		e["left"] = ""
		d[cid] = e
	else:
		var start: float = START_LOVE
		if from_club_id != "" and RivalryEngine.club_rival_for(world, cid, world_seed) == from_club_id:
			start = FROM_RIVAL_LOVE
			news = {"headline": "Llega desde el eterno rival y %s lo mira de reojo" % club_name,
				"body": "Viene del clásico rival: la afición lo espera con la ceja levantada.",
				"source": "AFICIÓN", "sentiment": "NEUTRAL"}
		d[cid] = _new_entry(club_name, start)
	player.active_effects[KEY] = d
	if not season.is_empty():
		var b: int = baseline(float(d[cid]["love"]))
		season["fan_baseline"] = b
		season["fan_sentiment"] = b
	return news

## Arranque de temporada en tu club: la afición empieza en su humor de base.
static func on_new_season(player: PlayerData, world: Dictionary, world_seed: int, season: Dictionary) -> void:
	if player == null or player.club_id == "" or season.is_empty():
		return
	bootstrap(player, world, world_seed)
	var b: int = baseline(float(entry(player, player.club_id).get("love", START_LOVE)))
	season["fan_baseline"] = b
	season["fan_sentiment"] = b

# --------------------------------------------------------------------------
#  Consumidores
# --------------------------------------------------------------------------

## Recibimiento en un ex club (ImmersionEngine.ex_club_reception):
## "traidor" | "idolo" | "ex" | "" (sin datos: que decida la regla vieja).
static func reception(player: PlayerData, host_club_id: String) -> String:
	var e: Dictionary = entry(player, host_club_id)
	if e.is_empty() or String(e.get("left", "")) == "" or host_club_id == player.club_id:
		return ""
	var lv: float = float(e.get("love", START_LOVE))
	if String(e.get("left", "")) == "rival" or lv < float(RECEPTION_HOSTILE):
		return "traidor"
	if lv >= float(RECEPTION_IDOL):
		return "idolo"
	return "ex"

## Legado (LegacyEngine.tier): +1 si alguna afición te tiene de ídolo.
static func legacy_points(player: PlayerData) -> int:
	var d: Dictionary = all(player)
	for cid in d:
		if float(d[cid].get("love", 0)) >= float(IDOL_LOVE) and String(d[cid].get("left", "")) != "rival":
			return 1
	return 0
