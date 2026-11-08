extends RefCounted
## Charla del descanso: además de la táctica del equipo, el míster te da UNA orden
## personal para la segunda parte ("tira más", "ayuda atrás", "busca el pase").
## Se mide solo lo que haces después del descanso (match_stats.me ahora menos la
## foto del descanso). Cumplirla sube su confianza; fallarla la baja un poco.
## Funciones puras: no tocan nodos ni UI.

const TRUST_MET := 4
const TRUST_FAIL := -2
const XP_MET := 30

## mode "min": hay que llegar a `need` (se puede cumplir antes del final).
## mode "max": no pasar de `need` en toda la segunda parte (se juzga al final);
## `also` exige además un mínimo de otra estadística para no cumplirla sin jugar.
## when: "behind" (vais perdiendo o empate), "ahead" (ganando) o "any".
const POOL := [
	{"id": "shoot", "label": "Remata 2 veces", "text": "quiero verte rematar: dos tiros tuyos.", "stat": "shots", "need": 2, "mode": "min",
		"pos": ["ST", "MF"], "when": "any"},
	{"id": "goal", "label": "Marca un gol", "text": "necesitamos tu gol. Atácalos.", "stat": "goals", "need": 1, "mode": "min",
		"pos": ["ST"], "when": "behind"},
	{"id": "create", "label": "Da un pase de gol", "text": "busca a los de arriba: dame un pase de gol.", "stat": "key_passes", "need": 1, "mode": "min",
		"pos": ["MF", "ST"], "when": "any"},
	{"id": "recover", "label": "Recupera 2 balones", "text": "ayuda atrás: recupera dos balones.", "stat": "recov", "need": 2, "mode": "min",
		"pos": ["DF", "MF"], "when": "any"},
	{"id": "hold", "label": "Cero errores atrás", "text": "cero errores atrás: recupera un balón y que no te salga mal ninguna jugada.", "stat": "moments_fail",
		"need": 0, "mode": "max", "also": {"recov": 1}, "pos": ["DF", "MF"], "when": "ahead"},
	{"id": "focus", "label": "Sin errores", "text": "sin errores: que no te salga mal ni una jugada.", "stat": "moments_fail", "need": 0, "mode": "max",
		"also": {"moments_ok": 1}, "pos": ["ST", "MF", "DF"], "when": "any"},
	{"id": "wall", "label": "Portería a cero", "text": "que no entre ni una más.", "stat": "conceded", "need": 0, "mode": "max",
		"pos": ["GK"], "when": "any"},
	{"id": "saves", "label": "Haz 2 paradas", "text": "te van a llegar: sácame dos paradas.", "stat": "saves", "need": 2, "mode": "min",
		"pos": ["GK"], "when": "behind"},
]


## La orden para tu puesto según cómo va el partido (score_diff = tuyos - suyos).
## roll en [0, 1). {} si no hay ninguna que encaje.
static func pick(role: String, score_diff: int, roll: float) -> Dictionary:
	var sit := "ahead" if score_diff > 0 else "behind"
	var opts: Array = []
	for o: Dictionary in POOL:
		if not (role in (o.pos as Array)):
			continue
		if String(o.when) != "any" and String(o.when) != sit:
			continue
		opts.append(o)
	if opts.is_empty():
		return {}
	return (opts[clampi(int(roll * opts.size()), 0, opts.size() - 1)] as Dictionary).duplicate(true)


## Cuánto llevas en la segunda parte de la estadística de la orden.
static func progress(order: Dictionary, base: Dictionary, me: Dictionary) -> int:
	var k := String(order.get("stat", ""))
	return int(me.get(k, 0)) - int(base.get(k, 0))


## ¿Ya cumplida a mitad de partido? Solo las de mínimo.
static func met_early(order: Dictionary, base: Dictionary, me: Dictionary) -> bool:
	return String(order.get("mode", "")) == "min" and progress(order, base, me) >= int(order.get("need", 0))


## Veredicto al final. sent_off = te echaron en la segunda parte (falla siempre).
static func met_final(order: Dictionary, base: Dictionary, me: Dictionary, sent_off: bool) -> bool:
	if order.is_empty() or sent_off:
		return false
	var v := progress(order, base, me)
	if String(order.get("mode", "")) == "min":
		return v >= int(order.get("need", 0))
	if v > int(order.get("need", 0)):
		return false
	var also: Dictionary = order.get("also", {})
	for k in also:
		if int(me.get(k, 0)) - int(base.get(k, 0)) < int(also[k]):
			return false
	return true


## "1/2" para el HUD (las de máximo enseñan "en curso").
static func progress_text(order: Dictionary, base: Dictionary, me: Dictionary) -> String:
	if String(order.get("mode", "")) == "min":
		return "%d/%d" % [mini(progress(order, base, me), int(order.need)), int(order.need)]
	return "en curso" if progress(order, base, me) <= int(order.get("need", 0)) else "fallada"
