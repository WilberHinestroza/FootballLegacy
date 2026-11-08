extends RefCounted
## Rasgos de jugador (Traits.gd) en el partido 3D, al estilo de los PlayStyles:
## los que llevas EQUIPADOS cambian de verdad tus jugadas (el portero te para
## menos, proteges y robas mejor, tus pases filtrados llegan más, te cansas menos)
## y, cuando uno decide la acción, el HUD enseña su icono.
##
## Las cantidades salen del catálogo de Traits (finish, set_piece, penalty,
## playmk, defense, fatigue_factor, concede_factor); aquí solo se traducen a las
## palancas del 3D. Funciones puras: no tocan nodos ni UI.

## Cuánto pesa cada bonus del catálogo en la palanca del 3D.
const KEEPER_BEATEN_K := 1.5    # finish/set_piece → +prob. de superar al portero
const PENALTY_BEATEN_K := 1.2   # penalty → idem en penaltis
const PROTECT_K := 3.0          # playmk → menos robos por contacto cuando llevas el balón
const STEAL_K := 4.0            # defense → más robos por contacto cuando defiendes
const SHOULDER_K := 1.5         # defense/playmk → duelos de hombro
const KEY_PASS_K := 1.5         # playmk → pase clave que termina en ocasión
const KEEPER_WALL_POW := 2.0    # concede_factor → tus paradas (si eres portero)


## Suma de los efectos de los rasgos equipados: {finish, set_piece, penalty,
## playmk, defense, fatigue_factor, concede_factor}.
static func mods(ids: Array) -> Dictionary:
	var out := {"finish": 0.0, "set_piece": 0.0, "penalty": 0.0, "playmk": 0.0, "defense": 0.0,
		"fatigue_factor": 1.0, "concede_factor": 1.0}
	for id in ids:
		var t: Dictionary = Traits.CATALOG.get(String(id), {})
		for k in ["finish", "set_piece", "penalty", "playmk", "defense"]:
			out[k] = float(out[k]) + float(t.get(k, 0.0))
		for k in ["fatigue_factor", "concede_factor"]:
			if t.has(k):
				out[k] = float(out[k]) * float(t[k])
	return out


## Lo que suma a la probabilidad de superar al portero en TU tiro.
## kind: "open" (jugada), "free_kick" o "penalty".
static func keeper_beaten_bonus(m: Dictionary, kind: String) -> float:
	match kind:
		"penalty":
			return float(m.get("penalty", 0.0)) * PENALTY_BEATEN_K
		"free_kick":
			return float(m.get("set_piece", 0.0)) * KEEPER_BEATEN_K
	return float(m.get("finish", 0.0)) * KEEPER_BEATEN_K


## Clave del catálogo que manda en cada tipo de tiro (para el icono).
static func shot_key(kind: String) -> String:
	return {"penalty": "penalty", "free_kick": "set_piece"}.get(kind, "finish")


## Si TÚ eres el portero: multiplica la probabilidad de que el tiro te supere.
static func keeper_wall_factor(m: Dictionary) -> float:
	return pow(float(m.get("concede_factor", 1.0)), KEEPER_WALL_POW)


## Ritmo de robo por contacto: multiplicador cuando tú llevas el balón (proteges)
## o cuando tú eres quien roba.
static func protect_factor(m: Dictionary) -> float:
	return maxf(0.4, 1.0 - float(m.get("playmk", 0.0)) * PROTECT_K)


static func steal_factor(m: Dictionary) -> float:
	return 1.0 + float(m.get("defense", 0.0)) * STEAL_K


## Ajuste a la prob. de ganar un duelo de hombro (+ si defiendes tú, - si llevas
## tú el balón y te protege la técnica).
static func shoulder_bonus(m: Dictionary, star_defending: bool) -> float:
	if star_defending:
		return float(m.get("defense", 0.0)) * SHOULDER_K
	return -float(m.get("playmk", 0.0)) * SHOULDER_K


static func key_pass_bonus(m: Dictionary) -> float:
	return float(m.get("playmk", 0.0)) * KEY_PASS_K


static func fatigue_factor(m: Dictionary) -> float:
	return float(m.get("fatigue_factor", 1.0))


## El rasgo equipado que más aporta a `key` (para el icono del HUD); "" si ninguno.
static func top_trait(ids: Array, key: String) -> String:
	var best := ""
	var best_v := 0.0
	for id in ids:
		var t: Dictionary = Traits.CATALOG.get(String(id), {})
		var v := float(t.get(key, 0.0))
		if key in ["fatigue_factor", "concede_factor"] and t.has(key):
			v = 1.0 - float(t[key])
		if v > best_v:
			best_v = v
			best = String(id)
	return best
