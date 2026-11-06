extends Node

## Prueba dirigida: "cuando me convocan a la selección, no me sale el
## partido en el calendario semanal" — Calendar._event_for_day() solo
## pre-veía partidos de ELIMINATORIA en días que no son "hoy"; un partido
## de MUNDIAL (o copa continental) en cualquier otro día del calendario
## nunca se marcaba, aunque ya estuviera programado de verdad. Instancia
## el SCRIPT suelto (Calendar.gd no tiene class_name) y llama
## _event_for_day() directo para un día de fase de grupos del Mundial que
## NO es "hoy" — mismo criterio que CalendarFifaWindowProbe.
##   godot --headless res://tools/CalendarWcPreviewProbe.tscn

func _ready() -> void:
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	WorldTickEngine.season = {"start_year": 2026, "season_start_epoch_day": 0}
	WorldTickEngine.current_epoch_day = 1 # bien lejos de cualquier jornada de grupos

	var cal_script: GDScript = load("res://scenes/Calendar/Calendar.gd")
	var cal = cal_script.new()
	cal._club_id = "c_1_0"
	cal._today_epoch_day = 1
	cal._nat_country = "Argentina" # está en el campo real del Mundial 2026 (WorldCupEngine.REAL_WC_2026_FIELD)

	var ok: bool = true

	# _build_days_grid() calcula _nat_wc/_nat_ncup/_nat_qualifying — acá se
	# replica solo esa parte (sin instanciar los nodos @onready del grid).
	var nat_confederation: String = Confederations.confederation_of("Argentina")
	cal._nat_qualifying = WorldTickEngine.national_qualifying_for(nat_confederation)
	cal._nat_wc = WorldTickEngine.world_cup_this_cycle()
	cal._nat_ncup = WorldTickEngine.national_cup_for(nat_confederation)

	if cal._nat_wc.is_empty():
		print("PROBE FAIL (no se armó el Mundial — ¿cambió el año base/campo real?)")
		get_tree().quit(1)
		return

	# Busca el primer día de fase de grupos de Argentina.
	var match_day: int = -1
	var opponent: String = ""
	for g in cal._nat_wc.get("groups", []) as Array:
		for fx in g.get("fixtures", []) as Array:
			if String(fx.get("home", "")) == "Argentina" or String(fx.get("away", "")) == "Argentina":
				match_day = int(fx.get("epoch_day", -1))
				opponent = String(fx.get("away", "")) if String(fx.get("home", "")) == "Argentina" else String(fx.get("home", ""))
				break
		if match_day >= 0:
			break
	if match_day < 0:
		print("PROBE FAIL (Argentina no tiene fixtures de grupo en el Mundial armado)")
		get_tree().quit(1)
		return
	print("día de partido de Mundial de Argentina: %d (vs %s) — hoy es el día %d" % [match_day, opponent, cal._today_epoch_day])

	var ev: Dictionary = cal._event_for_day(match_day)
	print("evento de ese día (NO es hoy): %s" % ev)
	if ev.is_empty():
		print("FALLA: un partido de Mundial programado en un día futuro debería marcarse en el calendario")
		ok = false
	elif ev.get("label", "").find(opponent) < 0:
		print("FALLA: el rival mostrado no coincide (%s)" % ev.get("label", ""))
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
