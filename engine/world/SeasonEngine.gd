extends RefCounted
class_name SeasonEngine

## Resultados de la temporada para TODO el mundo (mundo vivo).
##
## Filosofía (igual que WorldFactory): el resultado de cualquier partido de
## IA es una FUNCIÓN PURA de (world_seed, fixture). NO se persiste ningún
## resultado de IA — se recalcula al vuelo cuando hace falta una tabla.
## El save solo guarda los resultados REALES del usuario, que sobreescriben
## la simulación de su propio partido.
##
## season["results"]:  "L:<jornada>:<home_id>:<away_id>" -> [gh, ga]
##   (exclusivamente partidos que jugó el usuario)
##
## Nota: las semillas de sim usan hash() de Godot. Es estable dentro de una
## misma versión del motor; un cambio mayor de Godot podría rebarajar los
## resultados de IA (nunca los del usuario, que sí se guardan). Si algún
## día importa, sustituir por un hash propio estable.

## `epoch_day`: bug real encontrado en la auditoría (ronda 3) — antes la
## clave era SOLO (matchday, home, away), sin nada que la distinga entre
## temporadas. world_seed es fijo para TODA la carrera, así que si el
## mismo cruce (mismos dos clubes, mismo número de jornada) se repite en
## otra temporada — algo común, la mayoría de las ligas mantienen
## plantel/fixture estable de un año a otro — la tirada de RNG (goles,
## tarjetas vía DisciplineEngine, quién anota vía TopPerformersEngine) es
## LA MISMA de nuevo. `epoch_day` es único en toda la carrera (nunca se
## repite), así que alcanza para que cada temporada tenga su propia
## tirada sin tocar el resto de la fórmula. No rompe los overrides del
## usuario (season["results"] ya es un dict POR temporada — epoch_day
## agregado ahí es solo una parte más de una clave que de todas formas
## nunca se reutiliza entre temporadas).
static func league_result_key(matchday: int, home_id: String, away_id: String, epoch_day: int) -> String:
	return "L:%d:%s:%s:%d" % [matchday, home_id, away_id, epoch_day]

## Resultado [goles_local, goles_visitante] de un fixture de liga:
## override del usuario si existe; si no, simulación determinista.
static func league_result(fixture: Dictionary, world_seed: int, overrides: Dictionary, strength_by_club: Dictionary) -> Array:
	var key: String = league_result_key(int(fixture["matchday"]), fixture["home_club_id"], fixture["away_club_id"], int(fixture.get("epoch_day", 0)))
	if overrides.has(key):
		return overrides[key]
	var home_s: float = float(strength_by_club.get(fixture["home_club_id"], 55))
	var away_s: float = float(strength_by_club.get(fixture["away_club_id"], 55))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ world_seed
	return MatchSimulator.simulate(home_s, away_s, rng)

## ¿El usuario ya jugó (tiene override guardado) ese fixture de liga?
static func user_has_override(season: Dictionary, fixture: Dictionary) -> bool:
	if fixture.is_empty() or fixture.get("competition", "league") != "league":
		return false
	var key: String = league_result_key(
		int(fixture.get("matchday", 0)),
		fixture.get("home_club_id", ""),
		fixture.get("away_club_id", ""),
		int(fixture.get("epoch_day", 0)),
	)
	return season.get("results", {}).has(key)

## Guarda el resultado REAL de un partido de liga jugado por el usuario.
static func record_user_league_result(season: Dictionary, fixture: Dictionary, home_goals: int, away_goals: int) -> void:
	if fixture.get("competition", "league") != "league":
		return
	var results: Dictionary = season.get("results", {})
	var key: String = league_result_key(
		int(fixture.get("matchday", 0)),
		fixture.get("home_club_id", ""),
		fixture.get("away_club_id", ""),
		int(fixture.get("epoch_day", 0)),
	)
	results[key] = [home_goals, away_goals]
	season["results"] = results

# =====================================================================
#  AMISTOSO (pretemporada) — nunca cuenta para tabla ni objetivos, solo
#  para que el partido no se re-simule distinto si se vuelve a mirar ese
#  día. Namespace de clave propio ("F:") para no chocar con liga/copa.
# =====================================================================

static func friendly_result_key(index: int, home_id: String, away_id: String) -> String:
	return "F:%d:%s:%s" % [index, home_id, away_id]

static func user_has_friendly_override(season: Dictionary, fixture: Dictionary) -> bool:
	if fixture.is_empty() or fixture.get("competition", "") != "friendly":
		return false
	var key: String = friendly_result_key(
		int(fixture.get("index", 0)), fixture.get("home_club_id", ""), fixture.get("away_club_id", ""),
	)
	return season.get("results", {}).has(key)

## Guarda el resultado REAL de un amistoso jugado por el usuario.
static func record_user_friendly_result(season: Dictionary, fixture: Dictionary, home_goals: int, away_goals: int) -> void:
	if fixture.get("competition", "") != "friendly":
		return
	var results: Dictionary = season.get("results", {})
	var key: String = friendly_result_key(
		int(fixture.get("index", 0)), fixture.get("home_club_id", ""), fixture.get("away_club_id", ""),
	)
	results[key] = [home_goals, away_goals]
	season["results"] = results

# =====================================================================
#  COPA (eliminatoria)
# =====================================================================
#
# El cuadro se RESUELVE al vuelo con resolve_cup(): a partir de la
# plantilla (season["cup"], generada por SeasonCalendar) + world_seed +
# fuerzas + overrides del usuario, rellena los emparejamientos de cada
# ronda con los ganadores de la anterior y simula lo ya disputado.
# Nada de esto se persiste: es una vista determinista. Solo se guardan
# los resultados que juega el usuario.
#
# override de copa:  "C:<ronda>:<home_id>:<away_id>" -> {"score":[gh,ga], "winner":"home"|"away"}

static func cup_result_key(round_num: int, home_id: String, away_id: String) -> String:
	return "C:%d:%s:%s" % [round_num, home_id, away_id]

## Días entre ida y vuelta — ÚNICA fuente (antes vivía solo como copia en
## WorldTickEngine.CUP_SECOND_LEG_GAP; auditoría ronda 2: "si resolve_cup
## también necesita el hueco de 7 días, que no tenga su propio literal
## duplicado" — CLAUDE.md, "nunca una fórmula de balance en dos archivos").
## WorldTickEngine debería referenciar ESTA constante en vez de la suya.
const CUP_SECOND_LEG_GAP := 7

## Devuelve el cuadro con emparejamientos y resultados resueltos hasta hoy.
## Estructura de cada match resuelto:
##   {home_club_id, away_club_id, is_knockout, result: [gh,ga]|null, winner_club_id: ""}
## `two_legged_until_final`: si true, cada ronda salvo la Final se resuelve
## a IDA Y VUELTA (agregado, penales solo si el agregado queda empatado) —
## mismo criterio que WorldTickEngine._next_user_cup_fixture() ya usa para
## el cruce del propio usuario. Bug real de la auditoría: resolve_cup()
## SIEMPRE resolvía a partido único, correcto para Mundial/Club World Cup
## (de verdad son así) pero MAL para el resto de las copas de fondo
## (domésticas de otros países, continentales de club) que en este juego
## sí son ida y vuelta salvo la final — los cruces de fondo (todo lo que
## el usuario no juega él mismo) nunca miraban el agregado. Default false:
## ningún llamador existente cambia de comportamiento a menos que pase
## true explícitamente.
static func resolve_cup(cup_template: Dictionary, world_seed: int, strength_by_club: Dictionary, overrides: Dictionary, current_epoch_day: int, two_legged_until_final: bool = false) -> Dictionary:
	if cup_template.is_empty():
		return {}
	var rounds_in: Array = cup_template.get("rounds", [])
	var out_rounds: Array = []
	var prev_winners: Array = []
	var chain_alive: bool = true   # ¿siguen decididas todas las rondas hasta aquí?

	for i in range(rounds_in.size()):
		var rt: Dictionary = rounds_in[i]
		var rnd: Dictionary = {
			"round": int(rt.get("round", i + 1)),
			"round_name": rt.get("round_name", ""),
			"epoch_day": int(rt.get("epoch_day", 0)),
			"byes": (rt.get("byes", []) as Array).duplicate(),
			"matches": [],
			"decided": false,
		}

		# Emparejamientos de esta ronda.
		var pairings: Array = []
		var template_has_ids: bool = false
		for m in rt.get("matches", []):
			if m.get("home_club_id", "") != "" and m.get("away_club_id", "") != "":
				template_has_ids = true
				break

		if i == 0 or template_has_ids:
			for m in rt.get("matches", []):
				pairings.append([m.get("home_club_id", ""), m.get("away_club_id", "")])
		elif chain_alive:
			var entrants: Array = []
			if i == 1:
				entrants.append_array(rounds_in[0].get("byes", []))
			entrants.append_array(prev_winners)
			var j: int = 0
			while j + 1 < entrants.size():
				pairings.append([entrants[j], entrants[j + 1]])
				j += 2

		# Si aún no se pueden formar (ronda anterior sin decidir), placeholders
		# con la forma de la plantilla — el cuadro siempre tiene esqueleto completo.
		if pairings.is_empty():
			for _m in rt.get("matches", []):
				pairings.append(["", ""])

		var pairings_ok: bool = not pairings.is_empty()
		for p in pairings:
			if p[0] == "" or p[1] == "":
				pairings_ok = false

		# Dos legs salvo la Final — ver doc de two_legged_until_final arriba.
		var is_two_legged: bool = two_legged_until_final and String(rnd["round_name"]) != "Final"
		var decide_by_day: int = int(rnd["epoch_day"]) + (CUP_SECOND_LEG_GAP if is_two_legged else 0)

		var this_winners: Array = []
		var all_played: bool = pairings_ok and chain_alive
		for p in pairings:
			var m: Dictionary = {
				"home_club_id": p[0], "away_club_id": p[1], "is_knockout": true,
				"result": null, "winner_club_id": "",
			}
			if pairings_ok and chain_alive:
				var key: String = cup_result_key(rnd["round"], p[0], p[1])
				if overrides.has(key):
					var ov: Dictionary = overrides[key]
					m["result"] = ov.get("score", [0, 0])
					m["winner_club_id"] = p[0] if ov.get("winner", "home") == "home" else p[1]
				elif decide_by_day < current_epoch_day:
					var hs: float = float(strength_by_club.get(p[0], 55))
					var away_s: float = float(strength_by_club.get(p[1], 55))
					if is_two_legged:
						# Ida: p[0] local. Vuelta: p[1] local (localía invertida,
						# mismo criterio que _next_user_cup_fixture) — semilla
						# propia por leg para que no sea el mismo marcador dos
						# veces. Agregado en la orientación de la ida (p[0]/p[1]).
						var rng1 := RandomNumberGenerator.new()
						rng1.seed = hash(key) ^ world_seed
						var leg1: Array = MatchSimulator.simulate(hs, away_s, rng1)
						var rng2 := RandomNumberGenerator.new()
						rng2.seed = hash(key + "|leg2") ^ world_seed
						var leg2: Array = MatchSimulator.simulate(away_s, hs, rng2)
						m["result"] = [int(leg1[0]) + int(leg2[1]), int(leg1[1]) + int(leg2[0])]
						m["leg1_result"] = leg1
						m["leg2_result"] = leg2
					else:
						var rng := RandomNumberGenerator.new()
						rng.seed = hash(key) ^ world_seed
						m["result"] = MatchSimulator.simulate(hs, away_s, rng)
					var dec: Dictionary = _knockout_decide(p[0], p[1], m["result"], hs, away_s, world_seed, key)
					m["winner_club_id"] = dec["winner"]
					if not (dec["pens"] as Array).is_empty():
						m["pens"] = dec["pens"]   # [ph, pa] — se resolvió por penales
				else:
					all_played = false
			else:
				all_played = false
			rnd["matches"].append(m)
			if m["winner_club_id"] != "":
				this_winners.append(m["winner_club_id"])

		rnd["decided"] = all_played
		out_rounds.append(rnd)

		if all_played:
			prev_winners = this_winners
		else:
			chain_alive = false
			prev_winners = []

	return {
		"cup_id": cup_template.get("cup_id", ""),
		"cup_name": cup_template.get("cup_name", ""),
		"rounds": out_rounds,
	}

static func _knockout_winner(home_id: String, away_id: String, score: Array, home_str: float, away_str: float, world_seed: int, key: String) -> String:
	return _knockout_decide(home_id, away_id, score, home_str, away_str, world_seed, key)["winner"]

## Resuelve un cruce a partido único: si hay empate en los 90 va a prórroga
## y penales (siempre hay ganador). Devuelve {winner, pens: [ph,pa]|[]}.
## `pens` solo se llena si de verdad se llegó a la tanda.
static func _knockout_decide(home_id: String, away_id: String, score: Array, home_str: float, away_str: float, world_seed: int, key: String) -> Dictionary:
	if int(score[0]) > int(score[1]):
		return {"winner": home_id, "pens": []}
	if int(score[1]) > int(score[0]):
		return {"winner": away_id, "pens": []}
	# empate -> (prórroga sin goles) -> penales: moneda sesgada por fuerza.
	var p_home: float = clampf(0.5 + (home_str - away_str) * 0.012, 0.2, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + "|pens") ^ world_seed
	var home_wins: bool = rng.randf() < p_home
	var loser: int = rng.randi_range(2, 4)
	var winner_p: int = loser + rng.randi_range(1, 2)
	var pens: Array = [winner_p, loser] if home_wins else [loser, winner_p]
	return {"winner": home_id if home_wins else away_id, "pens": pens}

## Partido de copa del `club_id` en `epoch_day` dentro de un cuadro ya
## resuelto (resolve_cup), o {}.
static func cup_fixture_for_club_on(resolved_cup: Dictionary, epoch_day: int, club_id: String) -> Dictionary:
	if resolved_cup.is_empty() or club_id == "":
		return {}
	for rnd in resolved_cup.get("rounds", []):
		if int(rnd["epoch_day"]) != epoch_day:
			continue
		for m in rnd["matches"]:
			if m["home_club_id"] == club_id or m["away_club_id"] == club_id:
				return {
					"competition": "cup", "round": rnd["round"], "round_name": rnd["round_name"],
					"epoch_day": epoch_day, "home_club_id": m["home_club_id"],
					"away_club_id": m["away_club_id"], "is_knockout": true,
				}
	return {}

## Estado del usuario en la copa: {status, round_name, [epoch_day, home_club_id, away_club_id...]}.
## status: "upcoming" (hay partido por jugar), "advancing", "eliminated",
## "champion", "out" (no participa / no clasificado).
static func user_cup_summary(resolved_cup: Dictionary, club_id: String) -> Dictionary:
	if resolved_cup.is_empty() or club_id == "":
		return {"status": "out"}
	var state: Dictionary = {"status": "out"}
	for rnd in resolved_cup.get("rounds", []):
		var my_match: Dictionary = {}
		for m in rnd["matches"]:
			if m["home_club_id"] == club_id or m["away_club_id"] == club_id:
				my_match = m
				break
		if my_match.is_empty():
			if (rnd.get("byes", []) as Array).has(club_id):
				state = {"status": "advancing", "round_name": rnd["round_name"] + " (exento)"}
			continue
		if my_match["result"] == null:
			return {
				"status": "upcoming", "round_name": rnd["round_name"], "epoch_day": int(rnd["epoch_day"]),
				"home_club_id": my_match["home_club_id"], "away_club_id": my_match["away_club_id"],
				"round": int(rnd["round"]), "is_knockout": true, "competition": "cup",
			}
		if my_match["winner_club_id"] == club_id:
			state = {"status": ("champion" if rnd["round_name"] == "Final" else "advancing"), "round_name": rnd["round_name"]}
		else:
			return {"status": "eliminated", "round_name": rnd["round_name"]}
	return state

## Guarda el resultado REAL de un partido de copa jugado por el usuario.
static func record_user_cup_result(season: Dictionary, fixture: Dictionary, home_goals: int, away_goals: int, winner_side: String) -> void:
	if fixture.get("competition", "") != "cup":
		return
	var results: Dictionary = season.get("results", {})
	var key: String = cup_result_key(int(fixture.get("round", 0)), fixture.get("home_club_id", ""), fixture.get("away_club_id", ""))
	var w: String = winner_side
	if w != "home" and w != "away":
		w = "home" if home_goals >= away_goals else "away"
	results[key] = {"score": [home_goals, away_goals], "winner": w}
	season["results"] = results

static func user_has_cup_override(season: Dictionary, fixture: Dictionary) -> bool:
	if fixture.get("competition", "") != "cup":
		return false
	var key: String = cup_result_key(int(fixture.get("round", 0)), fixture.get("home_club_id", ""), fixture.get("away_club_id", ""))
	return season.get("results", {}).has(key)
