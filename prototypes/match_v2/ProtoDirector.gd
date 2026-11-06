extends RefCounted
const Rules = preload("res://prototypes/match_v2/ProtoRules.gd")
## Prototipo match_v2 — DIRECTOR del partido por JUGADAS (17-oct, Wilber:
## "que sean jugadas puntuales por partido para ir organizándolo para sumarlo
## al juego base"). En vez de 90 minutos seguidos, el partido es una lista de
## momentos donde participás vos (como los momentos clave del juego base):
## cada uno arranca en su minuto, con la cancha armada para esa situación
## (ProtoSim.setup_play), y termina cuando se define (gol, atajada, pérdida,
## pelota afuera, recuperación). Entre jugada y jugada el reloj salta.
##
## Puro: no sabe de UI ni de la simulación. Al integrarlo al juego base, esta
## lista la armaría el MatchEngine (mismo rol que sus "momentos").

## Jugadas posibles y su peso según tu puesto (más de lo que te toca hacer).
const WEIGHTS := {
	"ST": {"ataque": 3.0, "contra": 1.6, "centro": 1.6, "corner": 1.0, "tiro_libre": 0.9, "penal": 0.35, "defensa": 1.2},
	"MF": {"ataque": 3.0, "contra": 1.4, "centro": 1.0, "corner": 0.9, "tiro_libre": 1.0, "penal": 0.25, "defensa": 1.4},
	"DF": {"ataque": 1.5, "contra": 0.8, "centro": 0.5, "corner": 1.0, "tiro_libre": 0.6, "penal": 0.15, "defensa": 3.2},
}
const LABELS := {
	"ataque": "Ataque elaborado", "contra": "¡Contraataque!", "centro": "Centro al área",
	"corner": "Córner a favor", "tiro_libre": "Tiro libre al borde del área", "penal": "¡PENAL a favor!",
	"defensa": "El rival ataca: a defender",
}

var plays: Array = [] # [{"min": int, "kind": String, "bg": [equipo que hizo gol "fuera de cámara", ...]}]
var idx: int = -1
var results: Array = [] # lo que pasó en cada una (lo llena la escena)

func _init(seed_i: int, role: String, count: int = 8) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var w: Dictionary = WEIGHTS.get(role, WEIGHTS["ST"])
	var total: float = 0.0
	for k in w:
		total += float(w[k])
	# Minutos repartidos (uno por tramo, con algo de azar) para que no se amontonen.
	var span: float = 88.0 / float(count)
	var penals: int = 0
	for i in range(count):
		var m: int = clampi(int(2.0 + span * i + rng.randf_range(0.0, span * 0.8)), 1, 90)
		var r: float = rng.randf() * total
		var kind: String = "ataque"
		for k in w:
			r -= float(w[k])
			if r <= 0.0:
				kind = k
				break
		if kind == "penal":
			penals += 1
			if penals > 1:
				kind = "ataque" # a lo sumo un penal de regalo por partido
		# Mientras tanto (entre la jugada anterior y esta) el partido siguió:
		# a veces cae un gol que no jugaste (de tu equipo o del rival).
		var bg: Array = []
		if i > 0:
			if rng.randf() < Rules.BG_GOAL_RIVAL:
				bg.append(1)
			if rng.randf() < Rules.BG_GOAL_OWN:
				bg.append(0)
		plays.append({"min": m, "kind": kind, "bg": bg})
	# Siempre arranca con una jugada abierta (no con una pelota parada).
	if plays[0]["kind"] in ["corner", "tiro_libre", "penal"]:
		plays[0]["kind"] = "ataque"

func has_next() -> bool:
	return idx + 1 < plays.size()

func next() -> Dictionary:
	idx += 1
	return plays[idx]

func current() -> Dictionary:
	return plays[idx] if idx >= 0 and idx < plays.size() else {}

static func label(kind: String) -> String:
	return String(LABELS.get(kind, kind))
