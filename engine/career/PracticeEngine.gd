extends RefCounted
class_name PracticeEngine

## PRÁCTICA (8-nov, Wilber: "agregar un botón para entrar a práctica y ahí poder
## practicar o práctica libre o practicar cada faceta … y hasta jugar un partido
## titulares vs suplentes … que haya retos en esta sección que si se cumplen te den
## XP, máximo 2 por semana").
##
## La práctica NO avanza el día ni cuenta para tus estadísticas, la forma o el
## cansancio: es el partido 3D con jugadas elegidas. Lo único que se guarda son los
## retos de la semana, en season["practice"] (estado de temporada, igual que
## season["weekly_goals"]; no es un campo de PlayerData, no cambia el esquema).
## Sin la clave (partidas viejas) se crean al entrar: no hace falta migración.

## Retos que se pueden cobrar por semana (cumplirlos da la XP al instante).
const MAX_CLAIMS_PER_WEEK := 2
## Retos que se ofrecen cada semana.
const OFFERED := 4
## Jugadas por sesión de práctica libre o por faceta.
const SESSION_MOMENTS := 6

## Facetas: qué familias de jugada (PlayGenerator.FAMILIES) se practican en cada una.
## who: "gk" = solo porteros; "field" = solo jugadores de campo.
const FACETS := {
	"remate": {"label": "Remate", "desc": "Mano a mano, ocasiones y rechaces", "who": "field",
		"families": ["elaborado", "mano_a_mano", "rechace", "frontal", "balon_largo"]},
	"regate": {"label": "Regate", "desc": "Encarar, recortar y superioridades", "who": "field",
		"families": ["desborde", "diagonal", "superioridad", "mano_a_mano"]},
	"pase": {"label": "Pase", "desc": "Entre líneas, cambios de orientación, paredes", "who": "field",
		"families": ["entre_lineas", "cambio_orientacion", "contra_rapida", "pared", "salida_presion"]},
	"aereo": {"label": "Centros y cabezazos", "desc": "Centros al área y córners", "who": "field",
		"families": ["centro", "corner"]},
	"balon_parado": {"label": "Balón parado", "desc": "Faltas, penaltis y córners: los cobras tú", "who": "field",
		"families": ["tiro_libre", "penalti", "corner"]},
	"defensa": {"label": "Defensa", "desc": "Duelos, coberturas, persecuciones", "who": "field",
		"families": ["duelo", "dos_contra_uno", "repliegue", "persecucion", "ultimo_hombre", "presion_alta", "centro_rival", "corner_contra"]},
	"porteria": {"label": "Portería", "desc": "Remates, mano a mano, penaltis y centros", "who": "gk",
		"families": ["remate_area", "mano_a_mano_gk", "disparo_lejano", "penalti_contra", "tiro_libre_contra", "centro_gk", "corner_gk"]},
	"saque": {"label": "Juego con el pie", "desc": "Sacar jugando bajo presión", "who": "gk",
		"families": ["saque_arquero"]},
}

## Retos. kind:
##   goals / assists / saves   tus goles, asistencias o paradas en una sesión (de `facet` si la hay)
##   ok_facet   jugadas logradas en una sesión de `facet`
##   perfect    sesión (libre o por faceta) de al menos `target` jugadas sin fallar ninguna
##   scrim_win / scrim_contrib / scrim_clean   titulares contra suplentes: ganar,
##              marcar o asistir, portería a cero
## who: "field" / "gk" / "any".
const POOL := [
	{"id": "remate3", "kind": "goals", "facet": "remate", "target": 3, "xp": 60, "who": "field", "desc": "Marca 3 goles en la práctica de Remate"},
	{"id": "regate4", "kind": "ok_facet", "facet": "regate", "target": 4, "xp": 55, "who": "field", "desc": "Supera 4 jugadas en la práctica de Regate"},
	{"id": "pase2", "kind": "assists", "facet": "pase", "target": 2, "xp": 55, "who": "field", "desc": "Da 2 asistencias en la práctica de Pase"},
	{"id": "aereo2", "kind": "goals", "facet": "aereo", "target": 2, "xp": 65, "who": "field", "desc": "Marca 2 goles en Centros y cabezazos"},
	{"id": "parado2", "kind": "goals", "facet": "balon_parado", "target": 2, "xp": 65, "who": "field", "desc": "Marca 2 goles a balón parado"},
	{"id": "defensa5", "kind": "ok_facet", "facet": "defensa", "target": 5, "xp": 55, "who": "field", "desc": "Supera 5 jugadas en la práctica de Defensa"},
	{"id": "perfect", "kind": "perfect", "facet": "", "target": 5, "xp": 80, "who": "any", "desc": "Completa una sesión de práctica sin fallar ninguna jugada"},
	{"id": "scrim_win", "kind": "scrim_win", "facet": "", "target": 1, "xp": 50, "who": "any", "desc": "Gana el partido de titulares contra suplentes"},
	{"id": "scrim_contrib", "kind": "scrim_contrib", "facet": "", "target": 1, "xp": 50, "who": "field", "desc": "Marca o asiste en titulares contra suplentes"},
	{"id": "paradas4", "kind": "saves", "facet": "porteria", "target": 4, "xp": 60, "who": "gk", "desc": "Haz 4 paradas en la práctica de Portería"},
	{"id": "saque4", "kind": "ok_facet", "facet": "saque", "target": 4, "xp": 50, "who": "gk", "desc": "Saca jugando bien 4 veces en una sesión"},
	{"id": "scrim_clean", "kind": "scrim_clean", "facet": "", "target": 1, "xp": 70, "who": "gk", "desc": "Deja la portería a cero ante los suplentes"},
]


## Facetas disponibles para tu puesto, en el orden de la UI.
static func facets_for(is_gk: bool) -> Array:
	var out: Array = []
	for k: String in FACETS:
		if (String(FACETS[k].who) == "gk") == is_gk:
			out.append(k)
	return out


## Familias de jugada de una faceta.
static func families(facet: String) -> Array:
	return (FACETS.get(facet, {}) as Dictionary).get("families", [])


static func _week(day: int) -> int:
	return CalendarUtils.week_index(day)


## Estado de la semana: {"week", "gk", "claims", "list": [{id, kind, facet, target, xp, desc, progress, done}]}.
## Lo crea (determinista por semana + semilla) si cambió la semana.
static func state(season: Dictionary, day: int, world_seed: int, is_gk: bool) -> Dictionary:
	var st: Dictionary = season.get("practice", {})
	var same_week := int(st.get("week", -1)) == _week(day)
	if not same_week or bool(st.get("gk", false)) != is_gk:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("practice:%d" % _week(day)) ^ world_seed
		var pool: Array = []
		for c: Dictionary in POOL:
			var who := String(c.who)
			if who == "any" or (who == "gk") == is_gk:
				pool.append(c.duplicate(true))
		var picks: Array = []
		while picks.size() < OFFERED and not pool.is_empty():
			var c2: Dictionary = pool.pop_at(rng.randi() % pool.size())
			c2["progress"] = 0
			c2["done"] = false
			picks.append(c2)
		# Si en la misma semana cambias de puesto, los cobros ya hechos siguen contando
		var claims := int(st.get("claims", 0)) if same_week else 0
		st = {"week": _week(day), "gk": is_gk, "claims": claims, "list": picks}
		season["practice"] = st
	return st


static func claims_left(st: Dictionary) -> int:
	return maxi(0, MAX_CLAIMS_PER_WEEK - int(st.get("claims", 0)))


## Lo que hiciste en una sesión, a partir del resultado del partido 3D
## (SoccerMatch.result()). mode: "free" / "facet" / "scrim".
static func session_summary(res: Dictionary, mode: String, facet: String) -> Dictionary:
	var st: Dictionary = res.get("stats", {})
	var me: Dictionary = st.get("me", {})
	var log: Array = st.get("moment_log", [])
	var ok := 0
	var fail := 0
	for m: Dictionary in log:
		if bool(m.get("ok", false)):
			ok += 1
		else:
			fail += 1
	var score: Array = res.get("score", [0, 0])
	return {"mode": mode, "facet": facet, "goals": int(me.get("goals", 0)), "assists": int(me.get("assists", 0)),
		"saves": int(me.get("saves", 0)), "ok": ok, "fail": fail, "moments": log.size(),
		"us": int(score[0]), "them": int(score[1])}


## Cuánto cuenta esta sesión para un reto (son "en una sesión": vale el mejor
## intento de la semana).
static func _value(c: Dictionary, s: Dictionary) -> int:
	var facet := String(c.get("facet", ""))
	var scrim := String(s.mode) == "scrim"
	if facet != "" and String(s.facet) != facet:
		return 0
	match String(c.kind):
		"goals": return int(s.goals)
		"assists": return int(s.assists)
		"saves": return int(s.saves)
		"ok_facet": return int(s.ok)
		"perfect": return int(s.moments) if (not scrim and int(s.fail) == 0) else 0
		"scrim_win": return 1 if scrim and int(s.us) > int(s.them) else 0
		"scrim_contrib": return 1 if scrim and int(s.goals) + int(s.assists) > 0 else 0
		"scrim_clean": return 1 if scrim and int(s.them) == 0 else 0
	return 0


## Aplica la sesión a los retos de la semana. Los que se cumplen dan su XP al
## momento, mientras queden cobros esta semana (MAX_CLAIMS_PER_WEEK).
## Devuelve {"completed": [desc], "xp", "levels", "locked": [desc cumplidos sin cobro]}.
static func apply_session(season: Dictionary, player: PlayerData, day: int, world_seed: int, s: Dictionary) -> Dictionary:
	var st := state(season, day, world_seed, player.position == "GK")
	var out := {"completed": [], "xp": 0, "locked": [], "levels": 0}
	for c: Dictionary in st.list:
		if bool(c.done):
			continue
		c.progress = maxi(int(c.progress), mini(_value(c, s), int(c.target)))
		if int(c.progress) < int(c.target):
			continue
		if claims_left(st) <= 0:
			(out.locked as Array).append(String(c.desc))
			continue
		c.done = true
		st.claims = int(st.claims) + 1
		var lv: Dictionary = ProgressionEngine.add_xp(player, int(c.xp))
		out.xp = int(out.xp) + int(c.xp)
		out.levels = int(out.levels) + int(lv.get("levels", 0))
		(out.completed as Array).append(String(c.desc))
	return out
