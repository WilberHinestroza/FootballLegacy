extends RefCounted
class_name CareerRpgEngine

## RPG de carrera ampliado (10-oct, Wilber: "expande más el RPG, que tenga
## más cosas, y agrega una sección en Mi Perfil para mirar esas cosas").
## Capa ENCIMA de lo que ya había (nivel/XP/habilidades de ProgressionEngine
## y SkillTree, rasgos de Traits): no reemplaza nada.
##
##   RANGO        nombre de tu etapa según el nivel (solo identidad).
##   ARQUETIPO    qué tipo de jugador sos según tus atributos (solo identidad).
##   MAESTRÍAS    3 ramas (definición / creación / defensa) que suben con lo
##                que HACÉS en los partidos (player.mastery, v34). Cada
##                nivel da un bonus chico y permanente a esa rama.
##   LOGROS       hitos con recompensa de XP de carrera, se cobran una vez
##                (player.achievements, v34).
##   FESTEJO DE FIRMA  tu celebración preferida (cosmetics_equipped
##                ["celebration"], sin campo nuevo).
##
## Toda la matemática vive acá; el bonus de maestría entra al balance por el
## MISMO camino que los rasgos (Traits.*_bonus → DecisionResolver).

# --- Rango ---------------------------------------------------------------

const RANKS := [
	[1, "Juvenil"], [6, "Promesa"], [12, "Profesional"], [20, "Figura"],
	[30, "Estrella"], [40, "Crack mundial"], [50, "Leyenda"],
]

static func rank_name(level: int) -> String:
	var out: String = String(RANKS[0][1])
	for r in RANKS:
		if level >= int(r[0]):
			out = String(r[1])
	return out

## [nombre del próximo rango, nivel al que llega] o ["", 0] si ya es el último.
static func next_rank(level: int) -> Array:
	for r in RANKS:
		if level < int(r[0]):
			return [String(r[1]), int(r[0])]
	return ["", 0]

# --- Arquetipo -----------------------------------------------------------

const ARCHETYPES := {
	"RIT": {"name": "Velocista", "desc": "Tu arma es la velocidad: ganás la espalda y nadie te alcanza."},
	"TIR": {"name": "Goleador", "desc": "Vivís para el gol. Donde hay un hueco, hay un remate."},
	"PAS": {"name": "Cerebro", "desc": "El equipo juega al ritmo que vos marcás."},
	"REG": {"name": "Gambeteador", "desc": "Con la pelota en los pies sos imprevisible."},
	"DEF": {"name": "Muro", "desc": "Leés la jugada antes y llegás siempre primero al cruce."},
	"FÍS": {"name": "Tanque", "desc": "Fuerza y resistencia: ganás todos los duelos y corrés los 90."},
}

## {key, name, desc, value} del atributo de carta más alto (desempate estable).
static func archetype(player: PlayerData) -> Dictionary:
	var best_key: String = "TIR"
	var best_v: int = -1
	for key in PlayerDevelopment.CARD_STAT_KEYS:
		var v: int = PlayerDevelopment.card_stat(player, String(key))
		if v > best_v:
			best_v = v
			best_key = String(key)
	var a: Dictionary = ARCHETYPES[best_key]
	return {"key": best_key, "name": String(a["name"]), "desc": String(a["desc"]), "value": best_v}

# --- Maestrías -----------------------------------------------------------

const MASTERY := {
	"finish": {"name": "Definición", "what": "goles", "color": "#e5484d"},
	"playmk": {"name": "Creación", "what": "pases clave y regates ganados", "color": "#3e63dd"},
	"defense": {"name": "Defensa", "what": "quites e intercepciones", "color": "#46a758"},
}
## Acciones acumuladas para cada nivel (1..10).
const MASTERY_STEPS := [5, 15, 30, 50, 80, 120, 170, 230, 300, 400]
const MASTERY_BONUS_PER_LEVEL := 0.004   # +0,4% por nivel → +4% al máximo

static func mastery_count(player: PlayerData, branch: String) -> int:
	return int(player.mastery.get(branch, 0)) if player != null else 0

static func mastery_level(player: PlayerData, branch: String) -> int:
	var c: int = mastery_count(player, branch)
	var lv: int = 0
	for s in MASTERY_STEPS:
		if c >= int(s):
			lv += 1
	return lv

## [hechas en este nivel, necesarias para el próximo] o [0, 0] en el tope.
static func mastery_progress(player: PlayerData, branch: String) -> Array:
	var c: int = mastery_count(player, branch)
	var lv: int = mastery_level(player, branch)
	if lv >= MASTERY_STEPS.size():
		return [0, 0]
	var prev: int = int(MASTERY_STEPS[lv - 1]) if lv > 0 else 0
	return [c - prev, int(MASTERY_STEPS[lv]) - prev]

static func mastery_bonus(player: PlayerData, branch: String) -> float:
	return float(mastery_level(player, branch)) * MASTERY_BONUS_PER_LEVEL

## Suma lo que hiciste en un partido (rating_events del MatchEngine).
## Devuelve las ramas que subieron de nivel: [{branch, level}].
static func add_match_actions(player: PlayerData, rating_events: Array) -> Array:
	var before := {}
	for b in MASTERY:
		before[b] = mastery_level(player, String(b))
	for ev in rating_events:
		var branch: String = ""
		match String(ev.get("type", "")):
			"goal": branch = "finish"
			"key_pass_success": branch = "playmk"
			"tackle_success": branch = "defense"
		if branch != "":
			player.mastery[branch] = int(player.mastery.get(branch, 0)) + 1
	var ups: Array = []
	for b in MASTERY:
		var now: int = mastery_level(player, String(b))
		if now > int(before[b]):
			ups.append({"branch": String(b), "level": now})
	return ups

# --- Logros --------------------------------------------------------------

## check: clave de _value(); xp: XP de carrera al cobrarlo.
const ACHIEVEMENTS := [
	{"id": "debut", "name": "El primer día", "desc": "Jugá tu primer partido oficial.", "check": "matches", "min": 1, "xp": 60},
	{"id": "m50", "name": "Ya sos del plantel", "desc": "50 partidos de carrera.", "check": "matches", "min": 50, "xp": 150},
	{"id": "m150", "name": "Hombre de experiencia", "desc": "150 partidos de carrera.", "check": "matches", "min": 150, "xp": 300},
	{"id": "m300", "name": "Histórico", "desc": "300 partidos de carrera.", "check": "matches", "min": 300, "xp": 500},
	{"id": "g1", "name": "Rompiste el hielo", "desc": "Tu primer gol.", "check": "goals", "min": 1, "xp": 60},
	{"id": "g25", "name": "Olfato", "desc": "25 goles de carrera.", "check": "goals", "min": 25, "xp": 180},
	{"id": "g100", "name": "Club de los 100", "desc": "100 goles de carrera.", "check": "goals", "min": 100, "xp": 450},
	{"id": "g200", "name": "Goleador de época", "desc": "200 goles de carrera.", "check": "goals", "min": 200, "xp": 800},
	{"id": "a20", "name": "Buen socio", "desc": "20 asistencias de carrera.", "check": "assists", "min": 20, "xp": 180},
	{"id": "a75", "name": "El que hace jugar", "desc": "75 asistencias de carrera.", "check": "assists", "min": 75, "xp": 450},
	{"id": "t1", "name": "La primera vuelta", "desc": "Ganá tu primer título.", "check": "trophies", "min": 1, "xp": 250},
	{"id": "t5", "name": "Vitrina llena", "desc": "5 títulos.", "check": "trophies", "min": 5, "xp": 600},
	{"id": "ind1", "name": "Premio individual", "desc": "Ganá un premio individual (Bota de Oro, MVP, 11 ideal...).", "check": "individual", "min": 1, "xp": 300},
	{"id": "bdo", "name": "El mejor del mundo", "desc": "Ganá el Balón de Oro.", "check": "ballon_dor", "min": 1, "xp": 1000},
	{"id": "cap1", "name": "Himno", "desc": "Debutá con la selección.", "check": "caps", "min": 1, "xp": 200},
	{"id": "cap50", "name": "Referente de la selección", "desc": "50 partidos con la selección.", "check": "caps", "min": 50, "xp": 600},
	{"id": "wc", "name": "Campeón del mundo", "desc": "Ganá el Mundial.", "check": "world_cup", "min": 1, "xp": 1200},
	{"id": "ov75", "name": "Jugador serio", "desc": "Llegá a media 75.", "check": "overall", "min": 75, "xp": 200},
	{"id": "ov85", "name": "Clase mundial", "desc": "Llegá a media 85.", "check": "overall", "min": 85, "xp": 500},
	{"id": "ov90", "name": "Fuera de serie", "desc": "Llegá a media 90.", "check": "overall", "min": 90, "xp": 900},
	{"id": "lv10", "name": "Subiendo", "desc": "Nivel de carrera 10.", "check": "level", "min": 10, "xp": 100},
	{"id": "lv25", "name": "Media carrera", "desc": "Nivel de carrera 25.", "check": "level", "min": 25, "xp": 250},
	{"id": "rep70", "name": "Te conocen en todos lados", "desc": "Reputación 70.", "check": "reputation", "min": 70, "xp": 250},
	{"id": "sen5", "name": "De la casa", "desc": "5 temporadas en el mismo club.", "check": "seniority", "min": 5, "xp": 300},
	{"id": "clubs3", "name": "Trotamundos", "desc": "Jugá en 4 clubes distintos.", "check": "former_clubs", "min": 3, "xp": 250},
	{"id": "nem3", "name": "Le tomaste la mano", "desc": "Ganale 3 veces a tu rival personal.", "check": "nemesis_wins", "min": 3, "xp": 250},
	{"id": "tr5", "name": "Con sello propio", "desc": "Desbloqueá 5 rasgos.", "check": "traits", "min": 5, "xp": 250},
	{"id": "mas5", "name": "Especialista", "desc": "Llevá una maestría al nivel 5.", "check": "mastery_max", "min": 5, "xp": 300},
	{"id": "mas10", "name": "Maestro", "desc": "Llevá una maestría al nivel 10.", "check": "mastery_max", "min": 10, "xp": 700},
	{"id": "rich", "name": "Asegurado de por vida", "desc": "Juntá 50 millones.", "check": "balance", "min": 50000, "xp": 300},
]

static func value_of(player: PlayerData, check: String) -> int:
	if player == null:
		return 0
	match check:
		"matches": return player.career_matches + player.season_matches_played
		"goals": return player.career_goals + player.season_goals
		"assists": return player.career_assists + player.season_key_passes
		"trophies": return player.trophies_won
		"caps": return player.caps
		"overall": return player.overall
		"level": return player.level
		"reputation": return player.reputation
		"seniority": return player.club_seniority
		"former_clubs": return player.former_clubs.size()
		"traits": return player.traits.size()
		"balance": return player.balance
		"leadership": return player.leadership
		"age": return player.age
		"individual":
			var n: int = 0
			for t in player.career_titles:
				if String(t.get("kind", "")) == "individual":
					n += 1
			return n
		"ballon_dor":
			var nb: int = 0
			for t in player.career_titles:
				if String(t.get("id", "")) == "ballon_dor":
					nb += 1
			return nb
		"world_cup":
			var nw: int = 0
			for t in player.career_titles:
				if String(t.get("id", "")) == "world_cup":
					nw += 1
			return nw
		"nemesis_wins":
			var w: int = 0
			for e in player.nemesis_log:
				if int(e.get("sign", 0)) > 0:
					w += 1
			return w
		"mastery_max":
			var mx: int = 0
			for b in MASTERY:
				mx = maxi(mx, mastery_level(player, String(b)))
			return mx
	if check.begins_with("attr:"):
		return int(player.get(check.substr(5)))
	return 0

static func is_claimed(player: PlayerData, id: String) -> bool:
	return id in player.achievements

## Cobra los logros cumplidos que falten: suma su XP de carrera y los marca.
## Devuelve los NUEVOS (dicts del catálogo) para avisar.
static func sync_achievements(player: PlayerData) -> Array:
	var out: Array = []
	if player == null:
		return out
	for a in ACHIEVEMENTS:
		var id: String = String(a["id"])
		if id in player.achievements:
			continue
		if value_of(player, String(a["check"])) >= int(a["min"]):
			player.achievements.append(id)
			ProgressionEngine.add_xp(player, int(a["xp"]))
			out.append(a)
	return out

static func achievements_done(player: PlayerData) -> int:
	return player.achievements.size() if player != null else 0

# --- Festejo de firma ----------------------------------------------------

const CELEBRATION_LABELS := {
	"celeb_rodillas": "De rodillas", "celeb_salto": "Salto", "celeb_avion": "Avioncito",
	"celeb_cielo": "Al cielo", "celeb_escudo": "Beso al escudo", "celeb_mortal": "Mortal",
	"celeb_baile": "Baile", "celeb_corazon": "Corazón", "celeb_silencio": "Silencio",
	"celeb_bebe": "Bebé", "celeb_pistolas": "Pistolas", "celeb_saludo": "Saludo militar",
	"celeb_aplauso": "Aplauso", "celeb_grito": "Grito",
	"celeb_brazos_cruzados": "Brazos cruzados", "celeb_dedos_cielo": "Dedos al cielo",
	"celeb_salto_giro": "Salto y brazos abajo", "celeb_surfero": "Saludo surfero",
	"celeb_meditacion": "Meditación", "celeb_brazos_abiertos": "Brazos abiertos",
	"celeb_robot": "Robot",
}

static func celebration_label(anim: String) -> String:
	return String(CELEBRATION_LABELS.get(anim, anim))

## Tu festejo de firma ("" = al azar como siempre).
static func signature_celebration(player: PlayerData) -> String:
	if player == null:
		return ""
	var id: String = String(player.cosmetics_equipped.get("celebration", ""))
	return id if id in Avatar.CELEBRATION_ANIMS else ""

static func set_signature_celebration(player: PlayerData, anim: String) -> void:
	if anim == "" or not (anim in Avatar.CELEBRATION_ANIMS):
		player.cosmetics_equipped.erase("celebration")
	else:
		player.cosmetics_equipped["celebration"] = anim
