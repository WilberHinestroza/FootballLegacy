extends Node

## Prueba dirigida del bug real reportado por Wilber: "en las fechas
## FIFA... casi que toda la semana pueda ir pasando los días para jugar
## dentro de esa semana, asignale días específicos y cuando llegue ese
## día, de una se pueda jugar". Causa raíz encontrada en
## WorldCupEngine.next_user_fixture(): a diferencia de
## NationalCupEngine.next_user_fixture()/QualifyingEngine.
## user_fixture_today() (que SÍ exigían epoch_day == current_epoch_day),
## a WorldCupEngine le faltaba ese chequeo — el parámetro
## `current_epoch_day` estaba ahí pero nunca se usaba, así que el
## partido de grupo del usuario aparecía como "pendiente hoy" CUALQUIER
## día desde que el campo del Mundial existía (día 0 en adelante),
## no solo su jornada real.
## No toca slot_1/slot_2 (usa slot_3, desechable).
##   godot --headless res://tools/WcFixtureDayGateProbe.tscn

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	var world_seed: int = 20260906
	var world: Dictionary = WorldFactory.build(world_seed)
	var strength_by_club: Dictionary = {}
	var meta_by_id: Dictionary = world.get("club_meta_by_id", {})
	for club_id in meta_by_id:
		strength_by_club[club_id] = int(meta_by_id[club_id].get("base_overall", 55))

	WorldTickEngine.world = world
	WorldTickEngine.world_seed = world_seed
	WorldTickEngine._strength_by_club = strength_by_club
	var season_start: int = 0
	WorldTickEngine.season = {"start_year": WorldCupEngine.WC_BASE_YEAR, "season_start_epoch_day": season_start}
	WorldTickEngine.current_epoch_day = WorldCupEngine.GROUP_START_OFFSET

	var wc: Dictionary = WorldTickEngine.world_cup_this_cycle()
	if wc.is_empty():
		print("PROBE FAIL (Mundial vacío en el día de arranque de grupos)")
		get_tree().quit(1)
		return

	# Cualquier país del campo real (Parte 91t) sirve — agarramos el
	# primero del primer grupo y su primer fixture.
	var groups: Array = wc.get("groups", []) as Array
	var country: String = String((groups[0]["standings"][0] as Dictionary)["club_id"])
	var fixtures: Array = groups[0]["fixtures"] as Array
	var target_fx: Dictionary = {}
	for fx in fixtures:
		if String(fx.get("home", "")) == country or String(fx.get("away", "")) == country:
			target_fx = fx
			break
	if target_fx.is_empty():
		print("PROBE FAIL (no se encontró fixture del país de prueba)")
		get_tree().quit(1)
		return
	var match_day: int = int(target_fx["epoch_day"])
	print("País de prueba: %s — su jornada 1 cae el día %d" % [country, match_day])

	var ok: bool = true

	var before: Dictionary = WorldCupEngine.next_user_fixture(wc, country, match_day - 1, {})
	print("día %d (antes): %s" % [match_day - 1, "vacío" if before.is_empty() else before])
	if not before.is_empty():
		print("FALLA: un día ANTES de su jornada no debería mostrar el partido como pendiente")
		ok = false

	var exact: Dictionary = WorldCupEngine.next_user_fixture(wc, country, match_day, {})
	print("día %d (exacto): %s" % [match_day, "vacío" if exact.is_empty() else exact])
	if exact.is_empty():
		print("FALLA: el día EXACTO de su jornada debería mostrar el partido como pendiente")
		ok = false

	var after: Dictionary = WorldCupEngine.next_user_fixture(wc, country, match_day + 1, {})
	print("día %d (después, sin jugarlo): %s" % [match_day + 1, "vacío" if after.is_empty() else after])
	if not after.is_empty():
		print("FALLA: un día DESPUÉS ya no debería seguir mostrando el mismo partido como 'de hoy' (se resuelve solo, como cualquier partido de IA que no jugaste)")
		ok = false

	print("PROBE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
