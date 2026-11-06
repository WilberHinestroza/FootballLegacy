extends "res://tools/ui_gallery_probe.gd"
## RPG ampliado + rasgos + patrocinios + animaciones de situación (10-oct).
## Chequeos de lógica y capturas reales. Carrera desechable en slot_3.
##   godot --path . --resolution 576x1024 res://tools/RpgProbe.tscn
var _fails: int = 0
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/rpg_%s.png" % name))

func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _open(path: String) -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _wait(30)
	return inst

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var p: PlayerData = SaveManager.load_player()

	# --- Lógica ---
	_check(CareerRpgEngine.rank_name(1) == "Juvenil" and CareerRpgEngine.rank_name(31) == "Estrella" and CareerRpgEngine.rank_name(50) == "Leyenda", "rangos por nivel")
	p.shooting = 88
	_check(CareerRpgEngine.archetype(p)["name"] == "Goleador", "arquetipo sale del atributo de carta más alto")
	p.shooting = 62
	var ups: Array = CareerRpgEngine.add_match_actions(p, [{"type": "goal"}, {"type": "goal"}, {"type": "goal"}, {"type": "goal"}, {"type": "goal"}, {"type": "key_pass_success"}])
	_check(ups.size() == 1 and ups[0]["branch"] == "finish" and CareerRpgEngine.mastery_level(p, "finish") == 1, "5 goles = maestría de definición nivel 1")
	_check(is_equal_approx(CareerRpgEngine.mastery_bonus(p, "finish"), 0.004) and is_equal_approx(Traits.finish_bonus(p), 0.004), "la maestría entra al balance por Traits.finish_bonus")
	p.mastery["finish"] = 9999
	_check(CareerRpgEngine.mastery_level(p, "finish") == 10 and is_equal_approx(CareerRpgEngine.mastery_bonus(p, "finish"), 0.04), "tope de maestría: nivel 10 = +4%")
	p.mastery = {"finish": 34, "playmk": 61, "defense": 7}
	p.career_goals = 30
	p.career_matches = 60
	p.level = 12
	var lv_before: int = p.level
	var xp_before: int = p.career_xp
	var got: Array = CareerRpgEngine.sync_achievements(p)
	_check(got.size() >= 4, "logros cobrados de una: %d" % got.size())
	_check(p.level > lv_before or p.career_xp > xp_before, "los logros dan XP de carrera")
	_check(CareerRpgEngine.sync_achievements(p).is_empty(), "un logro no se cobra dos veces")
	_check(Traits.CATALOG.size() == 38, "38 rasgos en el catálogo (%d)" % Traits.CATALOG.size())
	var cats := {}
	for tid in Traits.CATALOG:
		cats[Traits.category_of(String(tid))] = true
		if TraitEngine.rule_for(String(tid)).is_empty():
			_check(false, "rasgo sin regla de desbloqueo: " + String(tid))
	_check(cats.size() == 7, "los rasgos caen en las 7 categorías (%s)" % str(cats.keys()))
	var vet := PlayerData.new()
	vet.age = 33
	vet.composure = 84
	vet.caps = 31
	var un: Array = TraitEngine.check_unlocks(vet)
	_check("veteran" in un and "clutch" in un and "national_hero" in un and not ("golden_boy" in un), "rasgos nuevos se desbloquean por edad, atributo y selección")
	CareerRpgEngine.set_signature_celebration(p, "celeb_brazos_cruzados")
	_check(CareerRpgEngine.signature_celebration(p) == "celeb_brazos_cruzados" and not Avatar.config_for_player(p, 1).has("celebration"), "festejo de firma guardado sin ensuciar el avatar")
	for a in ["celeb_brazos_cruzados", "celeb_dedos_cielo", "celeb_salto_giro", "celeb_surfero", "celeb_meditacion", "celeb_brazos_abiertos", "celeb_robot", "llamada", "pensar", "sorpresa", "himno", "lamento", "firma", "puno"]:
		if not Avatar.has_anim(a):
			_check(false, "falta la animación " + a)
	var round_trip: PlayerData = PlayerData.from_save_dict(p.to_save_dict())
	_check(round_trip.mastery == p.mastery and round_trip.achievements == p.achievements, "achievements y mastery sobreviven al guardado")

	# --- Estado para las capturas ---
	p.traits = ["killer_instinct", "poacher", "speedster", "clutch", "captain"]
	p.equipped_traits = ["killer_instinct", "captain"]
	p.overall = 66
	p.sponsor = {"name": "Vortex Sport", "weekly_income": 94, "weeks_remaining": 18, "granted": ["chandal"]}
	p.boot_deal = {"brand": "aerion", "weekly_income": 41, "weeks_remaining": 37, "granted": ["guayos_blanco", "guayos_azul"]}
	p.cosmetics_owned = ["chandal", "guayos_blanco", "guayos_azul"]
	p.cosmetics_equipped["acc_feet"] = "guayos_blanco"
	var erng := RandomNumberGenerator.new()
	erng.seed = 5
	p.pending_season_event = SeasonEventEngine.generate_event(erng)
	SaveManager.save_player(p)

	var prof: Node = await _open("res://scenes/PlayerProfile/PlayerProfile.tscn")
	prof.call("_on_tab_pressed", "attrs")
	await _wait(20)
	_shot("attrs")
	prof.call("_on_tab_pressed", "traits")
	await _wait(20)
	_shot("traits")
	prof.call("_on_tab_pressed", "rpg")
	await _wait(20)
	_shot("tab_rank")
	for k in range(4):
		var pg = prof.find_children("*", "Pager", true, false)
		if pg.is_empty():
			break
		pg[0].call("goto_page", k + 1)
		await _wait(25)
		_shot(["mastery", "celebration", "achievements", "achievements2"][k])
		# Ninguna etiqueta puede quedar más alta que ancha×6 (= partida letra
		# por letra): es el bug de "Nivel 3 / 10" en vertical.
		for l in prof.find_children("*", "Label", true, false):
			if l.is_visible_in_tree() and l.size.x > 0.0 and l.size.x < 24.0 and l.size.y > 60.0:
				_check(false, "etiqueta partida letra por letra: '%s' (%s)" % [l.text, str(l.size)])
	prof.queue_free()
	await _wait(3)

	var sp: Node = await _open("res://scenes/Sponsors/Sponsors.tscn")
	_shot("sponsors")
	sp.queue_free()
	await _wait(3)
	var se: Node = await _open("res://scenes/SeasonEvent/SeasonEvent.tscn")
	_shot("season_event")
	se.queue_free()
	await _wait(3)
	var intl: Dictionary = SaveManager.load_international()
	intl["user_callup_status"] = {"called_up": true, "status": "regular", "seen": false}
	SaveManager.save_international(intl)
	var nc: Node = await _open("res://scenes/NationalCallUp/NationalCallUp.tscn")
	_shot("callup")
	nc.queue_free()
	await _wait(3)
	var cm: Node = await _open("res://scenes/CareerMenu/CareerMenu.tscn")
	_shot("career_menu")
	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
