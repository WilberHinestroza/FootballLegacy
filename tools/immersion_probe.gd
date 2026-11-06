extends Node
## Inmersión (10-oct): vestuario, rival personal, familia, tribuna, carta
## especial y semana de clásico. Chequeos de lógica + capturas REALES.
## Siembra una carrera en slot_3 (desechable). Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/ImmersionProbe.tscn
const WORLD_SEED := 4242
const OUT := "res://_pixellab_preview/ui/imm_%s.png"
var _fails: int = 0

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		_fails += 1

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % name))

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## El día vive en season["current_epoch_day"] (load_runtime lo relee).
func _set_day(d: int) -> void:
	WorldTickEngine.current_epoch_day = d
	WorldTickEngine.season["current_epoch_day"] = d
	SaveManager.save_season(WorldTickEngine.season)

func _seed_career() -> void:
	SaveManager.active_slot_id = "slot_3"
	SaveManager.save_slot("slot_3", {})
	SaveManager.save_world_seed(WORLD_SEED)
	var world := WorldFactory.build(WORLD_SEED)
	var p := PlayerData.new()
	p.player_name = "Tomás Herrera"
	p.country = "Argentina"
	p.position = "ST"
	p.detailed_position = "DC"
	p.age = 24
	p.birth_epoch_day = -24 * 365
	p.overall = 78
	p.potential = 86
	for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(s, 76)
	p.career_matches = 140
	p.career_goals = 60
	p.reputation = 74
	p.club_seniority = 5
	p.recent_ratings = [8.1, 7.9, 8.4, 7.6, 8.2]
	p.partner = {"name": "Camila Ríos", "since_day": -300}
	var lg0: LeagueData = world["leagues"][0]
	var club: ClubData = world["clubs_by_league"][lg0.league_id][3]
	p.club_id = club.club_id
	p.wage = 12
	p.contract_years_remaining = 3
	SaveManager.save_player(p)
	var season := SeasonCalendar.build_season(world, int(lg0.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, WORLD_SEED)
	season["fan_sentiment"] = 82
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame
	var p: PlayerData = SaveManager.load_player()
	var world: Dictionary = WorldTickEngine.world

	# --- Lógica pura ---
	var lr_good := ImmersionEngine.locker_room({"rating": 8.6, "goals": 2, "won": true, "key": "a", "you": "Tomás"})
	var lr_bad := ImmersionEngine.locker_room({"rating": 5.1, "won": false, "key": "b", "you": "Tomás"})
	_check(lr_good["coach_expr"] == "feliz" and lr_bad["coach_expr"] == "enojado", "vestuario: DT feliz con 8.6, enojado con 5.1")
	_check(ImmersionEngine.key_match_kind({"round_name": "Final", "competition": "cup"}, p) == "final", "familia: la final es partido clave")
	_check(ImmersionEngine.key_match_kind({"competition": "league"}, p) == "", "familia: un partido de liga común no lo es")
	var love := ImmersionEngine.crowd_banners(p, WORLD_SEED, 82, true, true, 9)
	var boo := ImmersionEngine.crowd_banners(p, WORLD_SEED, 20, true, false, 9)
	_check(love["kind"] == "love" and love["banners"].size() == 2, "tribuna: 2 pancartas de amor con afición contenta (%s)" % str(love["banners"]))
	_check(boo["kind"] == "boo", "tribuna: silbidos con afición crispada")
	_check(ImmersionEngine.special_card(p, 2026).get("id", "") == "racha", "carta: EN RACHA con promedio ≥ 7.8")
	var p2: PlayerData = p.duplicate()
	p2.career_titles = [{"id": "ballon_dor", "kind": "individual", "season": 2026, "metal": 1}]
	_check(ImmersionEngine.special_card(p2, 2026).get("id", "") == "premio", "carta: PREMIO tras un premio individual")
	var rival_id: String = RivalryEngine.club_rival_for(world, p.club_id, WORLD_SEED)
	var nem_club: String = ImmersionEngine.nemesis_club_id(world, p.club_id, WORLD_SEED)
	_check(nem_club != "" and nem_club != p.club_id, "rival personal: hay club (%s)" % nem_club)
	var squad: Array = WorldFactory.make_squad_with_transfers(world, nem_club, WORLD_SEED, int(WorldTickEngine.season.get("season_start_epoch_day", 0)))
	var nem := ImmersionEngine.pick_nemesis(squad, p.position)
	_check(nem.get("position", "") == "DF", "rival personal de un delantero es defensor (%s)" % String(nem.get("name", "?")))
	ImmersionEngine.log_nemesis_match(p, 10, 1, 2, 8.0, 2026, nem_club)
	ImmersionEngine.log_nemesis_match(p, 10, 1, 2, 8.0, 2026, nem_club)
	ImmersionEngine.log_nemesis_match(p, 40, -1, 0, 5.5, 2026, nem_club)
	var rec := ImmersionEngine.nemesis_record(p.nemesis_log)
	_check(rec["played"] == 2 and rec["won"] == 1 and rec["lost"] == 1 and rec["your_goals"] == 2, "historial del rival de carrera (idempotente por día)")
	# v34: ex clubes.
	var other: ClubData = world["clubs_by_league"][world["leagues"][0].league_id][7]
	var ex := p.duplicate() as PlayerData
	ex.former_clubs = []
	ex.club_seniority = 5
	ImmersionEngine.note_club_left(ex, world, other.club_id, 2026)
	var left_id: String = ex.club_id
	ex.club_id = other.club_id
	_check(ex.former_clubs.size() == 1 and ImmersionEngine.ex_club_reception(ex, world, left_id, WORLD_SEED) == "idolo", "ex club con 5 temporadas te recibe como ídolo")
	ex.former_clubs[0]["to_club_id"] = RivalryEngine.club_rival_for(world, left_id, WORLD_SEED)
	_check(ImmersionEngine.ex_club_reception(ex, world, left_id, WORLD_SEED) == "traidor", "si te fuiste a su clásico, sos traidor")
	_check(ImmersionEngine.crowd_banners(ex, WORLD_SEED, 50, false, false, 9, "traidor")["kind"] == "boo", "silbidos en tu ex cancha")
	var mig: Dictionary = SaveManager._migrate_if_needed({"schema_version": 33, "player": {"player_name": "X", "overall": 60}, "season": {"nemesis_log": [{"day": 5, "sign": 1}]}})
	_check(int(mig["schema_version"]) == 34 and mig["player"]["former_clubs"] == [] and mig["player"]["nemesis_log"].size() == 1, "migración v33 → v34 (rescata el historial de la temporada)")
	SaveManager.save_player(p)

	# --- Semana de clásico: ubicar el día 3 antes del clásico ---
	var derby_fx: Dictionary = {}
	var fxs: Array = WorldTickEngine.season.get("league_fixtures", [])
	var cands: Array = []
	for f in fxs:
		if f is Dictionary:
			var h: String = String(f.get("home_club_id", ""))
			var a: String = String(f.get("away_club_id", ""))
			if (h == p.club_id and a == rival_id) or (a == p.club_id and h == rival_id):
				cands.append(f)
	cands.sort_custom(func(x, y): return int(x["epoch_day"]) < int(y["epoch_day"]))
	# Avanzar como el juego real (día a día), dando por jugado cada partido
	# propio que aparezca, hasta 2 días antes del primer clásico.
	if not cands.is_empty():
		var target: int = int(cands[0]["epoch_day"]) - 2
		var guard: int = 0
		while WorldTickEngine.current_epoch_day < target and guard < 80:
			guard += 1
			var why: String = WorldTickEngine.advance_until(target)
			var pend: Dictionary = WorldTickEngine.pending_user_fixture()
			if not pend.is_empty():
				var uh: bool = String(pend.get("home_club_id", "")) == p.club_id
				WorldTickEngine.record_user_result(pend, 2 if uh else 0, 0 if uh else 2, "home" if uh else "away")
			elif why != "reached_target":
				break
		var nx: Dictionary = WorldTickEngine.next_user_fixture(p.club_id)
		if int(nx.get("epoch_day", -1)) == int(cands[0]["epoch_day"]):
			derby_fx = nx
		SaveManager.save_season(WorldTickEngine.season)
	_check(not derby_fx.is_empty(), "hay un clásico en el calendario (rival %s)" % rival_id)
	var dw := ImmersionEngine.derby_week(derby_fx, p.club_id, rival_id, WorldTickEngine.current_epoch_day)
	_check(int(dw.get("days_left", -1)) == 2, "semana de clásico: faltan 2 días")
	if derby_fx.is_empty():
		# Sin clásico no hay nada que capturar: salir YA (no dejar la ventana colgada).
		print("PROBE FAIL (%d)" % _fails)
		get_tree().quit(1)
		return

	# Hub.
	var hub: Node = (load("res://scenes/Hub/Hub.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hub)
	await _frames(30)
	_check(String(hub.next_match_label.text).contains("SEMANA DE CLÁSICO"), "Hub: cartel de semana de clásico")
	_shot("hub_derby")
	hub.queue_free()
	await _frames(3)

	# Social: feed + DM del rival.
	var soc: Node = (load("res://scenes/Social/Social.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(soc)
	await _frames(25)
	_shot("social_derby")
	soc.call("_on_tab_pressed", "messages")
	await _frames(15)
	_shot("social_dm")
	var ctx: Dictionary = soc.call("_rivalry_ctx")
	_check(bool(ctx.get("derby_week", false)) and String(ctx.get("nemesis", "")) != "", "Social: contexto de clásico con rival personal")
	soc.queue_free()
	await _frames(3)

	# PreMatch del clásico.
	_set_day(int(derby_fx["epoch_day"]))
	MatchLauncher.prepare(world, p, derby_fx, "res://scenes/Hub/Hub.tscn", false)
	_check(bool(MatchState.fixture.get("derby", false)), "el fixture del clásico viene marcado")
	var pm: Node = (load("res://scenes/PreMatch/PreMatch.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(pm)
	await _frames(30)
	_shot("prematch_top")
	var sc: ScrollContainer = pm.find_child("Scroll", true, false) as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 600
		await _frames(10)
	_shot("prematch_duel")
	pm.queue_free()
	await _frames(3)


	# MatchSummary: vestuario (resultado armado a mano).
	MatchState.match_result = {"score": {"home": 2 if home else 1, "away": 1 if home else 2}, "user_rating": 8.4,
		"user_goals": 1, "user_assists": 1, "player_ratings": [], "events": []}
	MatchState.return_scene = "res://scenes/Hub/Hub.tscn"
	var ms: Node = (load("res://scenes/MatchSummary/MatchSummary.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(ms)
	await _frames(60)
	var locker_found: bool = ms.find_children("*", "Label", true, false).any(func(l): return String(l.text) == "EN EL VESTUARIO")
	_check(locker_found, "MatchSummary: sección EN EL VESTUARIO")
	_shot("summary_locker")
	var p_after: PlayerData = SaveManager.load_player()
	_check(p_after.nemesis_log.size() == 3, "el clásico quedó en el historial del rival (%d)" % p_after.nemesis_log.size())
	ms.queue_free()
	await _frames(3)

	# Cartas: normal / racha / premio / ícono.
	var row := HBoxContainer.new()
	row.position = Vector2(8, 60)
	row.add_theme_constant_override("separation", 6)
	get_tree().root.add_child(row)
	var club: ClubData = WorldFactory.find_club(world, p.club_id)
	var plain: PlayerData = p.duplicate()
	plain.recent_ratings = []
	var icon: PlayerData = p.duplicate()
	icon.career_matches = 520
	icon.career_goals = 260
	icon.club_seniority = 10
	icon.career_titles = [{"id": "ballon_dor", "kind": "individual", "season": 2015, "metal": 1}, {"id": "ballon_dor", "kind": "individual", "season": 2016, "metal": 1}, {"id": "world_cup", "kind": "world", "season": 2014, "metal": 1}]
	icon.trophies_won = 8
	for pl in [plain, p, p2, icon]:
		row.add_child(UltimateCard.build(pl, club, 134))
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.size = Vector2(800, 1100)
	get_tree().root.add_child(bg)
	get_tree().root.move_child(bg, row.get_index())
	await _frames(20)
	_shot("cards")

	print("PROBE ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
