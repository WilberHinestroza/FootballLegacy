extends Node
## Schema v33: nivel/XP de carrera, árbol de habilidades, forma, intensidad.
##   godot --headless --path . res://tools/ProgressionProbe.tscn
var fails := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FALLA ") + msg)
	if not c:
		fails += 1

func _ready() -> void:
	# Migración v32 → v33.
	var data := {"schema_version": 32, "player": {"overall": 70, "player_name": "X"}}
	var mig: Dictionary = SaveManager._migrate_v32_to_v33(data)
	var mp: Dictionary = mig["player"]
	ok(int(mig["schema_version"]) == 33, "migración marca v33")
	ok(int(mp["level"]) == ProgressionEngine.initial_level(70) and int(mp["level"]) > 20, "media 70 → nivel %d" % int(mp["level"]))
	ok(int(mp["skill_points"]) == ProgressionEngine.points_up_to(int(mp["level"])), "puntos = niveles ya ganados (%d)" % int(mp["skill_points"]))
	ok(int(mp["mood"]) == 60 and (mp["dating"] as Dictionary).is_empty(), "vida social vacía")
	var p := PlayerData.from_save_dict(mp)
	ok(p.level == int(mp["level"]), "from_dict lee level")

	# Subir de nivel.
	var q := PlayerData.new()
	q.position = "ST"
	q.level = 4
	var r: Dictionary = ProgressionEngine.add_xp(q, ProgressionEngine.xp_to_next(4) + ProgressionEngine.xp_to_next(5) + 10)
	ok(q.level == 6 and int(r["levels"]) == 2, "2 niveles de golpe → nivel %d" % q.level)
	ok(int(r["points"]) == 3 and q.skill_points == 3, "nivel 5 da 2 puntos, nivel 6 da 1 (total %d)" % q.skill_points)
	ok(q.career_xp == 10, "sobra 10 XP")
	ok(ProgressionEngine.match_xp(8.5, 2, 1, true, true, false) > ProgressionEngine.match_xp(6.0, 0, 0, false, true, false), "jugar mejor paga más XP")

	# Árbol.
	ok(not SkillTree.can_unlock(q, "st_def2"), "no se salta la rama")
	ok(not SkillTree.can_unlock(q, "mf_cre1"), "no compra de otra posición")
	ok(SkillTree.unlock(q, "st_def1") and q.skill_points == 2, "compra st_def1 (1 pt)")
	ok(SkillTree.unlock(q, "st_def2") and q.skill_points == 0, "compra st_def2 (2 pts)")
	ok(not SkillTree.can_unlock(q, "st_def3"), "sin puntos no compra")
	var m: Array = DecisionResolver.rpg_meter_mods(q, "shot_on_goal")
	ok(is_equal_approx(float(m[0]), 1.06), "remate: zona verde ×%.2f" % float(m[0]))
	ok(is_equal_approx(float(DecisionResolver.rpg_meter_mods(q, "tackle")[0]), 1.0), "barrida no cambia")
	var base_need := DecisionResolver.pitch_shot_aim_score(0.5, 0.3, false)
	var with_skill := DecisionResolver.pitch_shot_aim_score(0.5, 0.3, false, q)
	ok(with_skill > base_need, "Ojo de halcón mejora la puntería (%.2f > %.2f)" % [with_skill, base_need])
	q.position = "MF"
	ok(SkillTree.total(q, "w_finish") == 0.0, "cambiar de puesto apaga las habilidades de otro puesto")
	q.position = "ST"

	# Forma.
	ok(ProgressionEngine.form(q) == 3, "sin partidos = forma normal")
	for x in [8.2, 8.0, 7.9, 8.4, 8.1, 8.3]:
		ProgressionEngine.push_rating(q, x)
	ok(q.recent_ratings.size() == 5 and ProgressionEngine.form(q) == 5, "5 notas altas = Enchufado")
	ok(float(DecisionResolver.rpg_meter_mods(q, "tackle")[0]) > 1.07, "forma alta ensancha la zona")

	# Fatiga y XP.
	var a := PlayerData.new()
	a.stamina = 60
	var b := PlayerData.new()
	b.stamina = 60
	b.position = "MF"
	b.skills = ["mf_box1"]
	ok(PlayerDevelopment.physical_fatigue_after_match(b) < PlayerDevelopment.physical_fatigue_after_match(a), "Pulmón: menos desgaste")

	# Intensidad.
	var c := PlayerData.new()
	c.fatigue_physical = 30.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var t: Dictionary = ProgressionEngine.after_training(c, "suave", rng)
	ok(float(t["recovered"]) > 0.0 and c.fatigue_physical < 30.0, "suave recupera energía")
	ok(ProgressionEngine.training_xp("intensa") > ProgressionEngine.training_xp("suave"), "intensa da más XP")
	# Vida social.
	var sp := PlayerData.new()
	sp.balance = 100
	var season := {}
	var met_any := false
	for d in range(0, 7 * 20, 7):
		var rr: Dictionary = SocialLifeEngine.do_outing(sp, season, "fiesta", "", d, 7)
		if String(rr.get("met", "")) != "":
			met_any = true
	ok(met_any, "saliendo solo se conoce a alguien (%d conocidas)" % sp.affinities.size())
	var r2: Dictionary = SocialLifeEngine.do_outing(sp, season, "cine", "", 7 * 19, 7)
	ok(not bool(r2["ok"]), "una sola salida por semana")
	var gid: String = String(sp.affinities.keys()[0])
	sp.balance = 1000
	var base_aff: int = int(sp.affinities[gid])
	SocialLifeEngine.do_outing(sp, season, "cena", gid, 7 * 30, 7)
	ok(int(sp.affinities[gid]) > base_aff, "cita sube afinidad (%d → %d)" % [base_aff, int(sp.affinities[gid])])
	sp.affinities[gid] = 95
	var yes := false
	for d in range(200, 260):
		if SocialLifeEngine.ask_out(sp, gid, d, 7):
			yes = true
			break
		sp.affinities[gid] = 95
	ok(yes and RelationshipEngine.has_partner(sp) and String(sp.partner["npc_id"]) == gid, "con afinidad alta acepta ser tu novia")
	sp.mood = 90
	ok(SocialLifeEngine.mood_width(sp) > 0.0, "ánimo alto ayuda en la cancha")
	# Ediciones doradas.
	var gp := PlayerData.new()
	gp.balance = 99999
	ok(not ShopEngine.buy_cosmetic(gp, "traje_oro"), "la dorada no se compra")
	gp.career_titles = [{"id": "league_3", "kind": "team"}, {"id": "world_cup", "kind": "world"}]
	var ng: Array = GoldEditions.sync(gp)
	ok(ng.has("chandal_oro") and ng.has("cuero_oro") and not ng.has("traje_oro"), "liga + Mundial desbloquean chándal y cuero dorados")
	ok(GoldEditions.sync(gp).is_empty(), "no se repite el aviso")
	# Patrocinio: prenda regalada.
	var sp2 := PlayerData.new()
	sp2.sponsor = {"name": "Vortex Sport", "weekly_income": 10, "weeks_remaining": 2}
	ok(SponsorEngine.grant_gift(sp2) == "chandal" and sp2.cosmetics_owned.has("chandal"), "el patrocinador regala su prenda")
	SponsorEngine.remove_gift(sp2)
	ok(not sp2.cosmetics_owned.has("chandal"), "al vencer se va la prenda regalada")
	# Canas.
	var old := PlayerData.new()
	old.age = 37
	old.player_name = "Viejo"
	var young := PlayerData.new()
	young.age = 25
	young.player_name = "Viejo"
	ok(String(Avatar.config_for_player(old, 1)["tint_hair"]) != String(Avatar.config_for_player(young, 1)["tint_hair"]), "canas a los 37")
	# P4/P5.
	ok(ProgressionEngine.match_xp(7.0, 1, 0, true, true, false, true) > ProgressionEngine.match_xp(7.0, 1, 0, true, true, false, false), "el clásico da más XP")
	ok(PrizeMoneyEngine.derby_win_bonus(1000) > 5, "prima del clásico")
	ok(DecisionResolver.derby_pressure(80) > 0.0 and DecisionResolver.derby_pressure(50) < 0.0, "presión del clásico según temple")
	ok(DecisionResolver.combo_ease("shot_on_goal", true) > 0.0 and DecisionResolver.combo_ease("tackle", true) == 0.0, "combo solo ayuda al remate")
	ok(DecisionResolver.header_timing_precision(0, 0.5) >= DecisionResolver.CLEAN_HIT and DecisionResolver.header_timing_precision(500, 0.5) < DecisionResolver.CLEAN_HIT, "cabezazo: a tiempo limpio, tarde no")
	ok(DecisionResolver.free_kick_wall_factor(0.0) < 1.0 and DecisionResolver.free_kick_wall_factor(0.9) > 1.0, "tiro libre: barrera al medio, palo bien")
	var cp := PlayerData.new()
	cp.club_id = "c1"
	var cs := {}
	var c0: int = SocialLifeEngine.chemistry(cp, cs)
	SocialLifeEngine.add_chemistry(cp, cs, 10)
	ok(SocialLifeEngine.chemistry(cp, cs) == c0 + 10, "la química sube")
	cp.club_id = "c2"
	ok(SocialLifeEngine.chemistry(cp, cs) <= 70, "club nuevo: química de nuevo")
	ok(DecisionResolver.chemistry_width("key_pass", 100) > 0.0 and DecisionResolver.chemistry_width("tackle", 100) == 0.0, "química ayuda a los pases")
	var ip := PlayerData.new()
	ip.injury_days_remaining = 20
	PlayerDevelopment.rush_injury(ip)
	ok(ip.injury_days_remaining == 11 and PlayerDevelopment.reinjury_active(ip), "apurar la vuelta: 11 días + riesgo")
	var ts := {"transfer_inbox": [{"id": "o1", "from_club_name": "X", "wage": 100, "created_day": 0}]}
	var tp := PlayerData.new()
	tp.overall = 70
	TransferOfferEngine.send_counter(ts, "o1", 1)
	ok(not TransferOfferEngine.can_counter(ts["transfer_inbox"][0]), "una sola contraoferta")
	var trng := RandomNumberGenerator.new()
	trng.seed = 3
	TransferOfferEngine.daily_tick(ts, tp, 2, trng)
	ok((ts["transfer_inbox"][0] as Dictionary).has("counter"), "todavía no respondieron (día 2)")
	var nw: Array = TransferOfferEngine.daily_tick(ts, tp, 3, trng)
	ok(nw.size() == 1, "el día 3 responden: %s" % (String(nw[0]["headline"]) if not nw.is_empty() else "-"))
	var es := {"transfer_inbox": [{"id": "o2", "from_club_name": "Y", "wage": 100, "created_day": 0}]}
	TransferOfferEngine.daily_tick(es, tp, 13, trng)
	ok((es["transfer_inbox"] as Array).is_empty(), "la oferta vence a los 12 días")
	print("PROBE %s (%d fallos)" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0)
