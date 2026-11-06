extends RefCounted
class_name Formations

## Formaciones + estilo de juego. Todo DETERMINISTA a partir de
## (world_seed, club_id) — nada se persiste, igual que el resto del "mundo
## vivo". El entrenador (CoachData, generado por WorldFactory) elige su
## formación y su estilo; el club tiene una identidad de juego que el DT
## suele —no siempre— respetar.

## def por formación: cuántos de campo por línea (GK siempre 1). `bias`
## sesga la xG del equipo (ofensivo/defensivo) y el reparto de momentos
## clave del usuario.
## Bug real encontrado en la auditoría: "4-3-3" acá decía ST:3, pero su
## propio SLOTS de abajo despliega EI/ED como extremos (posición ANCHA,
## Positions.broad_of() los cuenta como "MF", igual que MatchTeam los
## cuenta al armar la XI) — el 4-3-3 real de este juego solo tiene 1
## delantero centro (DC), no 3. xg_factor() usaba este ST:3 para un bonus
## de +4% de xG que el 4-3-3 nunca debió tener (todas las demás
## formaciones sí coinciden con su propio SLOTS).
const FORMATIONS := {
	"4-3-3":   {"DF": 4, "MF": 5, "ST": 1, "bias": "ofensivo"},
	"4-4-2":   {"DF": 4, "MF": 4, "ST": 2, "bias": "equilibrado"},
	"4-2-3-1": {"DF": 4, "MF": 5, "ST": 1, "bias": "equilibrado"},
	"3-5-2":   {"DF": 3, "MF": 5, "ST": 2, "bias": "ofensivo"},
	"5-3-2":   {"DF": 5, "MF": 3, "ST": 2, "bias": "defensivo"},
	"4-5-1":   {"DF": 4, "MF": 5, "ST": 1, "bias": "defensivo"},
}

## Los 10 puestos de campo de cada formación, EN DETALLE (códigos de
## Positions). Es la forma REAL que el DT quiere en el campo: un lateral
## por banda, centrales, extremos, etc. MatchTeam llena cada puesto con el
## jugador cuya posición (principal → secundaria → misma línea → el que
## haya) mejor encaje, y GUARDA en qué puesto lo puso (deployed) para que
## la alineación muestre "LI" aunque el jugador sea MCO de oficio.
## Pedido de Wilber: "algunas formaciones no tienen sentido (un LD sin LI,
## 2 ED)... la IA de los técnicos debe ser inteligente y planificadora".
const SLOTS := {
	"4-3-3":   ["LI", "DFC", "DFC", "LD", "MCD", "MC", "MC", "EI", "DC", "ED"],
	"4-4-2":   ["LI", "DFC", "DFC", "LD", "MI", "MC", "MC", "MD", "DC", "SD"],
	"4-2-3-1": ["LI", "DFC", "DFC", "LD", "MCD", "MCD", "EI", "MCO", "ED", "DC"],
	"3-5-2":   ["DFC", "DFC", "DFC", "MD", "MCD", "MC", "MC", "MI", "DC", "SD"],
	"5-3-2":   ["CAI", "DFC", "DFC", "DFC", "CAD", "MCD", "MC", "MC", "DC", "SD"],
	"4-5-1":   ["LI", "DFC", "DFC", "LD", "EI", "MC", "MCD", "MC", "ED", "DC"],
}

## Puestos de una formación (10 de campo). Respaldo: 4-3-3.
static func slots_for(formation: String) -> Array:
	return (SLOTS.get(formation, SLOTS["4-3-3"]) as Array).duplicate()

const PLAY_STYLES := ["Posesión", "Directo", "Contraataque", "Presión alta"]
const PHILOSOPHIES := ["Ofensivo", "Equilibrado", "Defensivo"]

## Identidad de juego del club — de su ambición + una tirada por club.
## Los grandes tienden a Posesión / Presión; los chicos a Contraataque /
## Directo.
static func club_style(club: ClubData, world_seed: int) -> String:
	if club == null:
		return "Directo"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("clubstyle:%s" % club.club_id) ^ world_seed
	var amb: int = int(club.league_ambition)
	if amb >= 70:
		return "Posesión" if rng.randf() < 0.6 else "Presión alta"
	if amb >= 45:
		return PLAY_STYLES[rng.randi() % PLAY_STYLES.size()]
	return "Contraataque" if rng.randf() < 0.6 else "Directo"

## Formación que usa un entrenador — de su estilo + la ambición del club.
static func formation_for(coach: CoachData, club: ClubData, world_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("formation:%s" % (coach.coach_id if coach != null else "none")) ^ world_seed
	var amb: int = int(club.league_ambition) if club != null else 50
	var style: String = coach.style if coach != null else "Pragmático"
	# Entrenadores exigentes/ambiciosos en clubes grandes: ofensivo.
	if amb >= 65 and style in ["Exigente", "Disciplinario"]:
		return ["4-3-3", "3-5-2", "4-2-3-1"][rng.randi() % 3]
	if amb <= 40 or style == "Pragmático":
		return ["4-5-1", "5-3-2", "4-4-2"][rng.randi() % 3]
	return FORMATIONS.keys()[rng.randi() % FORMATIONS.size()]

static func philosophy_for(coach: CoachData, formation: String) -> String:
	var b: String = FORMATIONS.get(formation, {}).get("bias", "equilibrado")
	match b:
		"ofensivo": return "Ofensivo"
		"defensivo": return "Defensivo"
		_: return "Equilibrado"

## El estilo del DT: suele alinearse con la identidad del club, con algo de
## personalidad propia.
static func play_style_for(coach: CoachData, club: ClubData, world_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pstyle:%s" % (coach.coach_id if coach != null else "none")) ^ world_seed
	var club_st := club_style(club, world_seed)
	if rng.randf() < 0.65:
		return club_st # respeta la identidad del club
	return PLAY_STYLES[rng.randi() % PLAY_STYLES.size()] # tiene su propia idea

static func line_counts(formation: String) -> Dictionary:
	var f: Dictionary = FORMATIONS.get(formation, FORMATIONS["4-3-3"])
	return {"GK": 1, "DF": int(f["DF"]), "MF": int(f["MF"]), "ST": int(f["ST"])}

## Ajuste multiplicativo a la xG del equipo según la filosofía y la línea
## de ataque de la formación (NO una segunda fórmula de balance: solo
## escala la xG que ya calcula MatchSimulator/MatchEngine).
static func xg_factor(formation: String, philosophy: String) -> float:
	var f := 1.0
	match philosophy:
		"Ofensivo": f *= 1.08
		"Defensivo": f *= 0.90
	var st: int = int(FORMATIONS.get(formation, {}).get("ST", 2))
	f *= 1.0 + (st - 2) * 0.04 # +4% por delantero extra, -4% si juega con 1
	return f

## Ajuste multiplicativo a la xG DEL RIVAL según la solidez defensiva de
## esta formación. Bug real de la auditoría de balance (ronda 6):
## xg_factor() de arriba solo escalaba la xG PROPIA — una formación
## "defensiva" restaba ataque propio sin sumar NADA a cambio, así que
## 3-5-2 dominaba estrictamente a 5-3-2/4-5-1 en diferencial de gol
## esperado (nunca convenía jugar defensivo). Esto le da el trade-off que
## faltaba: más líneas atrás = menos xG concedida; más gente arriba =
## más xG concedida. El llamador aplica esto a la xG DEL OTRO equipo,
## nunca a la propia (ver MatchEngine._setup).
static func defense_factor(formation: String, philosophy: String) -> float:
	var f := 1.0
	match philosophy:
		"Ofensivo": f *= 1.05
		"Defensivo": f *= 0.92
	var df: int = int(FORMATIONS.get(formation, {}).get("DF", 4))
	f *= 1.0 - (df - 4) * 0.03 # -3% de xG concedida por cada defensor de más, +3% por cada uno de menos
	return f

## Sesgo del reparto de momentos clave del usuario según el estilo del DT.
## Devuelve {kind: multiplicador} para aplicar sobre _KIND_WEIGHTS.
static func moment_bias(play_style: String) -> Dictionary:
	match play_style:
		"Posesión":
			return {"key_pass": 1.6, "through_ball": 1.5, "dribble": 1.2, "long_shot": 0.6}
		"Directo":
			return {"long_shot": 1.6, "shot_on_goal": 1.3, "aerial_duel": 1.4, "key_pass": 0.7}
		"Contraataque":
			return {"shot_on_goal": 1.3, "pressing": 1.3, "one_on_one": 1.4, "key_pass": 0.8}
		"Presión alta":
			return {"pressing": 1.8, "interception": 1.5, "tackle": 1.3}
		_:
			return {}
