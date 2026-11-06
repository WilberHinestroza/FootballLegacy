extends Node

## Prueba dirigida de que el REPECHAJE de segundos (UEFA/AFC/CAF) es
## JUGABLE por el usuario (segunda vuelta del Item 3, tras "hazlo todo" de
## la Parte 82 — antes se autosimulaba siempre). Construye un mundo real,
## ubica el día exacto del repechaje, confirma que
## QualifyingEngine.user_fixture_today() ofrece el cruce a uno de los 4
## países en juego (is_knockout=true, key "C:..."), y que grabar un
## override para esa clave cambia el resultado final (winner/eliminated)
## respecto a la simulación determinista por hash — igual criterio que
## national_summary_probe.gd con las fases de grupo.
##   godot --headless res://tools/QualifyingPlayoffProbe.tscn

const SEED := 20260906
const CONF := "UEFA"

func _ready() -> void:
	var world: Dictionary = WorldFactory.build(SEED)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))
	var strength_by_country: Dictionary = NationalTeamFactory.strength_by_country(world, strength_by_club)
	var windows: Array = SeasonCalendar.international_windows_in_range(0, QualifyingEngine.CYCLE_QUALIFYING_DAYS, 0)

	var playoff_day: int = int(QualifyingEngine.CYCLE_QUALIFYING_DAYS * QualifyingEngine.GROUP_PLAYOFF_OFFSET_FRAC)
	var problems: int = 0

	var res: Dictionary = QualifyingEngine.resolve(CONF, strength_by_country, SEED, playoff_day, 0, {}, windows)
	var pr: Dictionary = res.get("playoff_round", {})
	print("playoff_round día=%s matches=%d" % [pr.get("epoch_day", "?"), (pr.get("matches", []) as Array).size()])
	if pr.is_empty() or (pr.get("matches", []) as Array).is_empty():
		print("FALLA: no hay ronda de repechaje en el día esperado")
		problems += 1
		print("PROBE ", "FAIL" if problems > 0 else "OK")
		get_tree().quit(1)
		return

	var m0: Dictionary = pr["matches"][0]
	var home: String = String(m0.get("home_club_id", ""))
	var away: String = String(m0.get("away_club_id", ""))
	print("cruce de prueba: %s vs %s" % [home, away])

	# 1) user_fixture_today debe ofrecer este cruce a `home` en su día exacto.
	var fx: Dictionary = QualifyingEngine.user_fixture_today(res, home, playoff_day)
	var offered_ok: bool = not fx.is_empty() and bool(fx.get("is_knockout", false)) and String(fx.get("opponent", "")) == away and String(fx.get("key", "")).begins_with("C:")
	print("user_fixture_today(%s): %s" % [home, fx])
	if not offered_ok:
		print("FALLA 1: no ofreció el cruce de repechaje como partido jugable")
		problems += 1

	# 2) Fuera de ese día exacto (playoff_day - 1) no debe ofrecer nada del
	#    repechaje (todavía no le toca) — evita "spoilear" el cruce antes de
	#    tiempo o duplicarlo varios días.
	var res_before: Dictionary = QualifyingEngine.resolve(CONF, strength_by_country, SEED, playoff_day - 1, 0, {}, windows)
	var fx_before: Dictionary = QualifyingEngine.user_fixture_today(res_before, home, playoff_day - 1)
	if not fx_before.is_empty():
		print("FALLA 2: ofreció el repechaje un día antes de que tocara: %s" % fx_before)
		problems += 1

	# 3) Grabar un override forzando que gane AWAY (aunque el hash diga lo
	#    contrario) y re-resolver DESPUÉS del día del repechaje: away debe
	#    terminar en "direct", home en "eliminated" — el override manda,
	#    no la simulación rápida (mismo principio que el resto del juego:
	#    lo jugado de verdad nunca se re-simula).
	var key: String = String(fx.get("key", ""))
	var overrides: Dictionary = {key: {"score": [0, 3], "winner": "away"}}
	var res_after: Dictionary = QualifyingEngine.resolve(CONF, strength_by_country, SEED, playoff_day + 1, 0, overrides, windows)
	var direct: Array = res_after.get("direct", [])
	var eliminated: Array = res_after.get("eliminated", [])
	var away_qualified: bool = direct.has(away)
	var home_eliminated: bool = eliminated.has(home)
	print("con override away gana 3-0: away en direct=%s, home en eliminated=%s" % [away_qualified, home_eliminated])
	if not (away_qualified and home_eliminated):
		print("FALLA 3: el override no determinó el resultado del repechaje")
		problems += 1

	print("PROBE ", "OK" if problems == 0 else "FAIL (%d)" % problems)
	get_tree().quit(1 if problems > 0 else 0)
