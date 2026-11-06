extends RefCounted
class_name SocialLifeEngine

## VIDA FUERA DEL FÚTBOL (schema v33, 9-oct — Wilber: "salidas al cine,
## con la novia, a ver otros partidos, crear chicas para que el jugador
## conozca"). Toda la matemática vive acá; Lifestyle muestra y OutingScene
## anima.
##
## Estado: player.mood (0-100), player.affinities {girl_id: 0-100},
## player.dating {id, stage, since_day} y la pareja de siempre en
## player.partner {name, since_day, npc_id} (RelationshipEngine).
## Una salida por semana (season["outing_week"]).

## Chicas para conocer (personajes ficticios; sprite en
## assets/people/<id>.png, mismo estilo que tu jugador).
const GIRLS := [
	{"id": "valeria", "name": "Valeria", "job": "Periodista deportiva", "likes": ["cena", "partido"]},
	{"id": "camila", "name": "Camila", "job": "Estudiante de medicina", "likes": ["cine", "cena"]},
	{"id": "lucia", "name": "Lucía", "job": "Diseñadora gráfica", "likes": ["cine", "videojuegos"]},
	{"id": "daniela", "name": "Daniela", "job": "Profesora de baile", "likes": ["fiesta", "cena"]},
	{"id": "sofia", "name": "Sofía", "job": "Cantante", "likes": ["fiesta", "cine"]},
	{"id": "isabella", "name": "Isabella", "job": "Abogada", "likes": ["cena", "partido"]},
	{"id": "mariana", "name": "Mariana", "job": "Streamer", "likes": ["videojuegos", "fiesta"]},
	{"id": "renata", "name": "Renata", "job": "Fotógrafa", "likes": ["partido", "cine"]},
]

## Salidas: costo, ánimo, alivio mental, afinidad base (si vas con ella),
## chance de conocer a alguien (si vas solo), y riesgo.
const OUTINGS := {
	"cine": {"name": "Cine", "desc": "Una peli tranquila", "cost": 2, "mood": 8, "mental": 10.0, "aff": 8, "meet": 0.30},
	"cena": {"name": "Cena", "desc": "Restaurante con estilo", "cost": 6, "mood": 10, "mental": 8.0, "aff": 12, "meet": 0.25},
	"partido": {"name": "Ver un partido", "desc": "Desde la tribuna, como hincha", "cost": 3, "mood": 9, "mental": 6.0, "aff": 8, "meet": 0.20},
	"fiesta": {"name": "Fiesta", "desc": "Noche larga… ojo con la prensa", "cost": 5, "mood": 16, "mental": 14.0, "aff": 10, "meet": 0.45, "press_risk": 0.22},
	"videojuegos": {"name": "Videojuegos", "desc": "Con compañeros del club", "cost": 0, "mood": 6, "mental": 12.0, "aff": 6, "meet": 0.0, "team": true},
}

const AFF_DATING := 40     # pasan a "saliendo"
const AFF_PARTNER := 75    # se puede pedir que sea tu novia
const LIKE_BONUS := 8

static func girl(id: String) -> Dictionary:
	for g in GIRLS:
		if String(g["id"]) == id:
			return g
	return {}

static func sprite_path(id: String) -> String:
	return "res://assets/people/%s.png" % id

static func outing_week(day: int) -> int:
	return int(day / 7)

static func outing_used(season: Dictionary, day: int) -> bool:
	return int(season.get("outing_week", -1)) == outing_week(day)

## Chicas que ya conociste, ordenadas por afinidad.
static func known(player: PlayerData) -> Array:
	var out: Array = []
	for g in GIRLS:
		if player.affinities.has(String(g["id"])):
			out.append(g)
	out.sort_custom(func(a, b): return int(player.affinities[a["id"]]) > int(player.affinities[b["id"]]))
	return out

static func stage_of(player: PlayerData, id: String) -> String:
	if String(player.partner.get("npc_id", "")) == id:
		return "novia"
	var a: int = int(player.affinities.get(id, 0))
	if a >= AFF_DATING:
		return "saliendo"
	return "conociendo"

const STAGE_NAMES := {"conociendo": "Se están conociendo", "saliendo": "Están saliendo", "novia": "Tu novia"}

## Hacer una salida. `with_id` = chica que te acompaña ("" = solo / con
## compañeros). Devuelve el resultado para la escena:
## {ok, outing, with, mood, mental, aff, met, press, stage_up, cost}.
static func do_outing(player: PlayerData, season: Dictionary, kind: String, with_id: String, day: int, world_seed: int) -> Dictionary:
	var o: Dictionary = OUTINGS.get(kind, {})
	var res: Dictionary = {"ok": false, "outing": kind, "with": with_id, "mood": 0, "mental": 0.0, "aff": 0,
		"met": "", "press": false, "stage_up": "", "cost": int(o.get("cost", 0))}
	if o.is_empty() or outing_used(season, day) or player.balance < int(res["cost"]):
		return res
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("outing:%d:%s" % [day, kind]) ^ world_seed
	player.balance -= int(res["cost"])
	var mood_gain: int = int(o["mood"]) + (6 if with_id != "" else 0)
	player.mood = clampi(player.mood + mood_gain, 0, 100)
	res["mood"] = mood_gain
	var before_m: float = player.fatigue_mental
	player.fatigue_mental = maxf(0.0, player.fatigue_mental - float(o["mental"]))
	res["mental"] = before_m - player.fatigue_mental
	if with_id != "" and player.affinities.has(with_id):
		var g: Dictionary = girl(with_id)
		var gain: int = int(o["aff"]) + (LIKE_BONUS if (g.get("likes", []) as Array).has(kind) else 0) + rng.randi_range(-2, 3)
		var st_before: String = stage_of(player, with_id)
		player.affinities[with_id] = clampi(int(player.affinities[with_id]) + gain, 0, 100)
		res["aff"] = gain
		var st_after: String = stage_of(player, with_id)
		if st_after != st_before:
			res["stage_up"] = st_after
	elif with_id == "" and RelationshipEngine.has_partner(player) == false and rng.randf() < float(o.get("meet", 0.0)):
		var pool: Array = GIRLS.filter(func(g): return not player.affinities.has(String(g["id"])))
		if not pool.is_empty():
			var g2: Dictionary = pool[rng.randi() % pool.size()]
			player.affinities[String(g2["id"])] = 12
			res["met"] = String(g2["id"])
	if rng.randf() < float(o.get("press_risk", 0.0)):
		res["press"] = true
		player.reputation = maxi(0, player.reputation - 1)
		player.coach_trust = maxi(0, player.coach_trust - 2)
	if bool(o.get("team", false)):
		player.coach_trust = mini(100, player.coach_trust + 1)
		res["chem"] = CHEM_GAMES
		add_chemistry(player, season, CHEM_GAMES)
	season["outing_week"] = outing_week(day)
	res["ok"] = true
	return res

## ¿Le podés pedir que sea tu novia?
static func can_ask_out(player: PlayerData, id: String) -> bool:
	return not RelationshipEngine.has_partner(player) and int(player.affinities.get(id, 0)) >= AFF_PARTNER

## Pedirle que sea tu novia: con afinidad alta casi siempre dice que sí.
static func ask_out(player: PlayerData, id: String, day: int, world_seed: int) -> bool:
	if not can_ask_out(player, id):
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("askout:%d:%s" % [day, id]) ^ world_seed
	var chance: float = clampf(0.55 + float(int(player.affinities[id]) - AFF_PARTNER) / 50.0, 0.55, 0.95)
	if rng.randf() < chance:
		var g: Dictionary = girl(id)
		player.partner = {"name": String(g["name"]), "since_day": day, "npc_id": id}
		player.dating = {"id": id, "stage": "novia", "since_day": day}
		player.mood = mini(100, player.mood + 15)
		return true
	player.affinities[id] = maxi(0, int(player.affinities[id]) - 10)
	return false

static func break_up(player: PlayerData) -> void:
	var id: String = String(player.partner.get("npc_id", ""))
	if id != "":
		player.affinities[id] = 30
	player.partner = {}
	player.dating = {}
	player.mood = maxi(0, player.mood - 12)

## Tick semanal: el ánimo vuelve despacio a su base (más alta con pareja y
## buena casa); la afinidad con quien no ves baja un poco.
static func weekly_tick(player: PlayerData) -> void:
	var base: int = 55 + (8 if RelationshipEngine.has_partner(player) else 0)
	if player.mood > base:
		player.mood -= 2
	elif player.mood < base:
		player.mood += 2
	for id in player.affinities.keys():
		if String(player.partner.get("npc_id", "")) == String(id):
			continue
		player.affinities[id] = maxi(0, int(player.affinities[id]) - 1)

## --- QUÍMICA con el plantel (P5, 9-oct) -----------------------------------
## 0-100 en season["chemistry"] (de la temporada y del club: si cambiás de
## club arranca de nuevo). Sube jugando con ellos y con las noches de
## videojuegos; ensancha la zona de los pases (DecisionResolver).
const CHEM_MATCH := 3
const CHEM_GAMES := 6

static func chemistry(player: PlayerData, season: Dictionary) -> int:
	if player == null:
		return 0
	if String(season.get("chemistry_club", "")) != player.club_id:
		return clampi(20 + player.club_seniority * 15, 0, 70)
	return int(season.get("chemistry", 20))

static func add_chemistry(player: PlayerData, season: Dictionary, n: int) -> int:
	var c: int = clampi(chemistry(player, season) + n, 0, 100)
	season["chemistry"] = c
	season["chemistry_club"] = player.club_id
	return c

static func chemistry_label(c: int) -> String:
	if c >= 80:
		return "Hermandad"
	if c >= 60:
		return "Muy buena"
	if c >= 40:
		return "Buena"
	if c >= 25:
		return "En formación"
	return "Recién llegado"

## El clásico mueve el ánimo más que cualquier partido (P5).
static func derby_mood(player: PlayerData, won: bool, lost: bool) -> int:
	var d: int = 10 if won else (-8 if lost else 0)
	player.mood = clampi(player.mood + d, 0, 100)
	return d

## Efecto del ÁNIMO en la cancha (DecisionResolver lo suma a la zona).
static func mood_width(player: PlayerData) -> float:
	if player == null:
		return 0.0
	if player.mood >= 80:
		return 0.03
	if player.mood <= 25:
		return -0.04
	return 0.0

static func mood_label(m: int) -> String:
	if m >= 80:
		return "Feliz"
	if m >= 60:
		return "Bien"
	if m >= 40:
		return "Normal"
	if m >= 25:
		return "Bajoneado"
	return "Mal"
