extends RefCounted
class_name PositionChangeEngine

## Cambio de posición: pedirle al DT jugar en otro puesto, o aceptar que él te
## lo proponga (a partir de los 29, o antes si tus atributos encajan muchísimo
## mejor en otro lado: el extremo que pierde velocidad acaba de media punta).
##
## - ENCAJE (fit): cuánto encajan tus atributos en cada puesto fino (0-100).
##   El DT acepta según el encaje del puesto nuevo frente al tuyo y su confianza.
## - FAMILIARIDAD: tu puesto es 100, tu segunda posición 85; el resto arranca
##   según lo parecido que sea (misma línea y banda, etc.) y sube con cada
##   partido que juegas ahí. Al llegar a 100 queda como tu segunda posición.
##   Sin adaptar rindes algo menos en el 3D (DecisionResolver.m3d_position_stats),
##   también cuando el DT te pone fuera de tu puesto.
##
## Estado (sin cambio de esquema):
##   player.active_effects["pos_familiarity"] = {codigo: 0..100}
##   season["pos_change_done"]      -> ya cambiaste de puesto esta temporada
##   season["pos_change_last_ask"]  -> día de la última petición (enfriamiento)
##   season["pos_change_offer"]     -> {code, expires} propuesta del DT pendiente
##   season["pos_change_offered"]   -> el DT ya propuso esta temporada

const KEY := "pos_familiarity"
const MAIN_FAMILIARITY := 100
const SECOND_FAMILIARITY := 85
const MATCH_GAIN := 12
const ASK_COOLDOWN_DAYS := 45
const REFUSE_MARGIN := 8        # encaje por debajo del tuyo que el DT ni considera
const FAIL_TRUST := -1
const ACCEPT_TRUST := 2
const PROPOSE_AGE := 29
const PROPOSE_MARGIN := 4       # desde los 29: encaje mejor por este margen
const PROPOSE_MARGIN_YOUNG := 10
const OFFER_DAYS := 14

## Pesos de atributos por puesto (suman 1).
const FIT_WEIGHTS := {
	"DFC": {"strength": 0.3, "decision_making": 0.3, "speed": 0.15, "composure": 0.15, "passing": 0.1},
	"LD": {"speed": 0.3, "stamina": 0.25, "decision_making": 0.2, "passing": 0.15, "strength": 0.1},
	"LI": {"speed": 0.3, "stamina": 0.25, "decision_making": 0.2, "passing": 0.15, "strength": 0.1},
	"CAD": {"speed": 0.3, "stamina": 0.3, "passing": 0.2, "dribbling": 0.1, "decision_making": 0.1},
	"CAI": {"speed": 0.3, "stamina": 0.3, "passing": 0.2, "dribbling": 0.1, "decision_making": 0.1},
	"MCD": {"decision_making": 0.3, "passing": 0.25, "strength": 0.2, "stamina": 0.15, "composure": 0.1},
	"MC": {"passing": 0.35, "decision_making": 0.25, "control": 0.2, "stamina": 0.2},
	"MD": {"passing": 0.3, "stamina": 0.25, "dribbling": 0.2, "speed": 0.15, "control": 0.1},
	"MI": {"passing": 0.3, "stamina": 0.25, "dribbling": 0.2, "speed": 0.15, "control": 0.1},
	"MCO": {"passing": 0.3, "control": 0.25, "dribbling": 0.2, "decision_making": 0.15, "shooting": 0.1},
	"MP": {"passing": 0.25, "control": 0.25, "dribbling": 0.2, "shooting": 0.2, "composure": 0.1},
	"ED": {"speed": 0.35, "dribbling": 0.35, "control": 0.15, "shooting": 0.15},
	"EI": {"speed": 0.35, "dribbling": 0.35, "control": 0.15, "shooting": 0.15},
	"SD": {"shooting": 0.3, "dribbling": 0.25, "control": 0.2, "passing": 0.15, "speed": 0.1},
	"DC": {"shooting": 0.45, "strength": 0.2, "composure": 0.2, "control": 0.15},
}
const RIGHT := ["LD", "CAD", "MD", "ED"]
const LEFT := ["LI", "CAI", "MI", "EI"]
const LINE_ORDER := {"DF": 0, "MF": 1, "ST": 2}

## Puestos de campo en orden de presentación (DF → MF → ST).
static func outfield_codes() -> Array:
	var out: Array = []
	for e in Positions.DETAILED:
		if String(e["broad"]) != "GK":
			out.append(String(e["code"]))
	return out

static func _side(code: String) -> int:
	if code in RIGHT:
		return 1
	if code in LEFT:
		return -1
	return 0

## Encaje de tus atributos en un puesto (0-100).
static func fit(player: PlayerData, code: String) -> int:
	var w: Dictionary = FIT_WEIGHTS.get(code, {})
	if w.is_empty():
		return 0
	var total := 0.0
	for k in w:
		total += float(player.get(k)) * float(w[k])
	return clampi(int(round(total)), 0, 100)

## Familiaridad de partida con un puesto, sin contar lo que ya jugaste ahí.
static func base_familiarity(player: PlayerData, code: String) -> int:
	if code == player.detailed_position:
		return MAIN_FAMILIARITY
	if code == player.secondary_detailed_position:
		return SECOND_FAMILIARITY
	var a: String = Positions.broad_of(player.detailed_position)
	var b: String = Positions.broad_of(code)
	if a == "GK" or b == "GK":
		return 0
	var same_side: bool = _side(code) == _side(player.detailed_position)
	var gap: int = absi(int(LINE_ORDER.get(a, 1)) - int(LINE_ORDER.get(b, 1)))
	match gap:
		0:
			return 55 if same_side else 40
		1:
			return 30 if same_side else 20
	return 10

static func familiarity(player: PlayerData, code: String) -> int:
	var stored: Dictionary = player.active_effects.get(KEY, {})
	return maxi(int(stored.get(code, 0)), base_familiarity(player, code))

## Tras un partido jugado en `code`: suma familiaridad. Devuelve el puesto si
## acabas de dominarlo (queda como tu segunda posición), "" si no.
static func on_match_played(player: PlayerData, code: String) -> String:
	if code == "" or not FIT_WEIGHTS.has(code) or code == player.detailed_position:
		return ""
	var before: int = familiarity(player, code)
	var now: int = mini(before + MATCH_GAIN, MAIN_FAMILIARITY)
	var stored: Dictionary = player.active_effects.get(KEY, {})
	stored[code] = now
	player.active_effects[KEY] = stored
	if now >= MAIN_FAMILIARITY and before < MAIN_FAMILIARITY and player.secondary_detailed_position != code:
		player.secondary_detailed_position = code
		return code
	return ""

## "" si hoy puedes pedir un cambio; si no, el motivo.
static func blocker(player: PlayerData, season: Dictionary, today: int) -> String:
	if player == null or player.club_id == "":
		return "Sin club."
	if player.position == "GK":
		return "Los porteros no cambian de puesto."
	if bool(season.get("pos_change_done", false)):
		return "Ya cambiaste de puesto esta temporada."
	var last: int = int(season.get("pos_change_last_ask", -9999))
	if today - last < ASK_COOLDOWN_DAYS:
		return "Ya hablaste con el DT hace poco. Vuelve en %d días." % (ASK_COOLDOWN_DAYS - (today - last))
	return ""

## Probabilidad de que el DT acepte (0 si ni lo considera).
static func accept_chance(player: PlayerData, code: String) -> float:
	var cur: int = fit(player, player.detailed_position)
	var tf: int = fit(player, code)
	if tf < cur - REFUSE_MARGIN:
		return 0.0
	return clampf(0.4 + float(player.coach_trust - 50) / 100.0 + float(tf - cur) / 25.0, 0.1, 0.95)

## Pides jugar en `code`. Devuelve {ok, message}.
static func request(player: PlayerData, season: Dictionary, code: String, today: int, rng: RandomNumberGenerator, world_seed: int) -> Dictionary:
	var b: String = blocker(player, season, today)
	if b != "":
		return {"ok": false, "message": b}
	if not FIT_WEIGHTS.has(code) or code == player.detailed_position:
		return {"ok": false, "message": "Elige otro puesto."}
	season["pos_change_last_ask"] = today
	var chance: float = accept_chance(player, code)
	var label: String = Positions.label_of(code)
	if chance <= 0.0:
		player.coach_trust = clampi(player.coach_trust + FAIL_TRUST, 0, 100)
		return {"ok": false, "asked": true, "message": "El DT no te ve de %s: tus atributos encajan mejor donde estás." % label.to_lower()}
	if rng.randf() >= chance:
		player.coach_trust = clampi(player.coach_trust + FAIL_TRUST, 0, 100)
		return {"ok": false, "asked": true, "message": "El DT lo pensará, pero por ahora te quiere de %s." % Positions.label_of(player.detailed_position).to_lower()}
	apply_change(player, season, code, world_seed)
	player.coach_trust = clampi(player.coach_trust + ACCEPT_TRUST, 0, 100)
	return {"ok": true, "asked": true, "message": "Hecho: desde hoy juegas de %s. Te costará unos partidos adaptarte." % label.to_lower()}

## Aplica el cambio: el puesto viejo pasa a ser tu segunda posición.
static func apply_change(player: PlayerData, season: Dictionary, code: String, world_seed: int) -> void:
	# El dorsal sugerido depende del puesto: se fija el que llevas para que no cambie.
	var sn = player.active_effects.get(ShirtNumberEngine.KEY, {})
	if not (sn is Dictionary) or int((sn as Dictionary).get("number", 0)) <= 0:
		player.active_effects[ShirtNumberEngine.KEY] = {"club_id": player.club_id, "number": ShirtNumberEngine.number_for(player, world_seed)}
	var stored: Dictionary = player.active_effects.get(KEY, {})
	stored[code] = familiarity(player, code)
	player.active_effects[KEY] = stored
	var old: String = player.detailed_position
	player.detailed_position = code
	player.position = Positions.broad_of(code)
	player.secondary_detailed_position = old
	season["pos_change_done"] = true
	season.erase("pos_change_offer")

## Mejor puesto según tus atributos (el que el DT te propondría).
static func best_alternative(player: PlayerData) -> String:
	var best := ""
	var best_fit := -1
	for code in outfield_codes():
		if code == player.detailed_position:
			continue
		var f: int = fit(player, code)
		if f > best_fit:
			best_fit = f
			best = code
	return best

## ¿El DT te propone hoy un cambio? Devuelve la propuesta o {}.
static func coach_proposal(player: PlayerData, season: Dictionary, today: int) -> Dictionary:
	if player == null or player.position == "GK" or player.club_id == "":
		return {}
	if bool(season.get("pos_change_done", false)) or bool(season.get("pos_change_offered", false)):
		return {}
	var code: String = best_alternative(player)
	if code == "":
		return {}
	var margin: int = PROPOSE_MARGIN if player.age >= PROPOSE_AGE else PROPOSE_MARGIN_YOUNG
	if fit(player, code) < fit(player, player.detailed_position) + margin:
		return {}
	return {"code": code, "expires": today + OFFER_DAYS}

static func pending_offer(season: Dictionary, today: int) -> Dictionary:
	var o: Dictionary = season.get("pos_change_offer", {})
	if o.is_empty() or int(o.get("expires", 0)) < today:
		return {}
	return o

## Respuesta a la propuesta del DT.
static func answer_offer(player: PlayerData, season: Dictionary, accept: bool, world_seed: int) -> String:
	var o: Dictionary = season.get("pos_change_offer", {})
	season.erase("pos_change_offer")
	if o.is_empty():
		return ""
	var code: String = String(o.get("code", ""))
	if not accept:
		player.coach_trust = clampi(player.coach_trust + FAIL_TRUST, 0, 100)
		return "Le dices al DT que prefieres seguir de %s." % Positions.label_of(player.detailed_position).to_lower()
	apply_change(player, season, code, world_seed)
	player.coach_trust = clampi(player.coach_trust + ACCEPT_TRUST, 0, 100)
	return "Aceptas: desde hoy juegas de %s." % Positions.label_of(code).to_lower()
