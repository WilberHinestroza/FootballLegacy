extends Node
## Galería REAL de pantallas con una carrera sembrada en slot_3 (mundo
## procedural, NO toca el importado). Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/UiGalleryProbe.tscn -- Hub Shop ...
## Borrar después el slot_3.json real.
const WORLD_SEED := 4242

func _seed_career() -> void:
	SaveManager.active_slot_id = "slot_3"
	SaveManager.save_slot("slot_3", {})
	SaveManager.save_world_seed(WORLD_SEED)
	var world := WorldFactory.build(WORLD_SEED)
	var p := PlayerData.new()
	p.player_name = "Tomás Herrera"
	p.country = "Argentina"
	p.position = "MF"
	p.detailed_position = "MC"
	p.dominant_foot = "Derecho"
	p.origin = "Cantera"
	p.age = 19
	p.birth_epoch_day = -19 * 365
	p.overall = 64
	p.potential = 82
	for s in ["speed", "stamina", "strength", "control", "passing", "shooting", "dribbling", "decision_making", "composure"]:
		p.set(s, 62)
	p.ensure_potential_floor()
	var lg0: LeagueData = world["leagues"][0]
	var club: ClubData = world["clubs_by_league"][lg0.league_id][3]
	p.club_id = club.club_id
	p.wage = 12
	p.contract_years_remaining = 3
	p.balance = 4200
	p.market_value = TransferMarketEngine.market_value(p.overall, p.potential, p.age)
	SaveManager.save_player(p)
	var season := SeasonCalendar.build_season(world, int(lg0.league_id), 0, CalendarUtils.season_start_year(0), p.club_id, WORLD_SEED)
	SaveManager.save_season(season)
	WorldTickEngine.load_runtime()
	WorldTickEngine.advance_until(WorldTickEngine.current_epoch_day + 20)

func _ready() -> void:
	_seed_career()
	await get_tree().process_frame   # la raíz termina de armar sus hijos
	var names := OS.get_cmdline_user_args()
	for nm in names:
		var path := "res://scenes/%s/%s.tscn" % [nm, nm]
		if not ResourceLoader.exists(path):
			print("falta ", path)
			continue
		if nm == "PreMatch" or nm == "Match":
			# Prepara el próximo partido real de la carrera sembrada.
			var pl := SaveManager.load_player()
			var fx: Dictionary = WorldTickEngine.next_user_fixture(pl.club_id)
			MatchLauncher.prepare(WorldTickEngine.world, pl, fx, "res://scenes/Hub/Hub.tscn", false)
		if nm == "Hub" and OS.get_environment("HUB_EARLY") != "":
			# Partido dentro de unos días: Hub con "Planificar" + "Pasar el día / Avanzar"
			WorldTickEngine.current_epoch_day -= 3
		if nm == "CareerMenu" and OS.get_environment("CAREER_FULL") != "":
			# Peor caso de la columna izquierda: patrocinio + guayos
			var cp := SaveManager.load_player()
			cp.sponsor = {"name": "Nimbus Gear", "weekly_income": 240000, "weeks_remaining": 8}
			cp.boot_deal = {"brand": String(BootBrands.BRANDS[0]["id"]), "weekly_income": 111000, "weeks_remaining": 36}
			SaveManager.save_player(cp)
		if nm == "Sponsors":
			var bp := SaveManager.load_player()
			bp.boot_deal = {"brand": String(BootBrands.BRANDS[0]["id"]), "weekly_income": 111000, "weeks_remaining": 36}
			SaveManager.save_player(bp)
		if nm == "Shop":
			var sp := SaveManager.load_player()
			sp.cosmetics_owned = ["hoodie", "top_camisa_chinos", "bot_jeans", "mocasines"]
			sp.cosmetics_equipped = {"top": "top_camisa_chinos", "bottom": "bot_jeans", "acc_feet": "mocasines"}
			SaveManager.save_player(sp)
		if nm == "Transfers":
			WorldTickEngine.season["transfer_inbox"] = [
				{"id": "g1", "from_club_id": "", "from_club_name": "Club Prueba", "kind": "traspaso", "fee": 9000, "wage": 2400, "contract_years": 3, "role": "titular", "created_day": WorldTickEngine.current_epoch_day - 8, "window_day": 40},
				{"id": "g2", "from_club_id": "", "from_club_name": "Otro Club", "kind": "traspaso", "fee": 5000, "wage": 1800, "contract_years": 2, "role": "rotación", "created_day": WorldTickEngine.current_epoch_day, "window_day": 40,
					"counter": {"wage": 2250, "respond_day": WorldTickEngine.current_epoch_day + 2}},
			]
			SaveManager.save_season(WorldTickEngine.season)
		if nm == "SeasonEvent" or nm == "PlayerProfile":
			var ep := SaveManager.load_player()
			var erng := RandomNumberGenerator.new()
			erng.seed = 5
			ep.pending_season_event = SeasonEventEngine.generate_event(erng)
			ep.career_titles = [{"id": "league_3", "name": "Liga", "kind": "team", "season": 2027, "metal": 1}, {"id": "ballon_dor", "name": "Balón de Oro", "kind": "individual", "season": 2028, "metal": 1}, {"id": "world_cup", "name": "Mundial", "kind": "world", "season": 2030, "metal": 1}]
			ep.traits = ["killer_instinct", "speedster", "mentor"]
			SaveManager.save_player(ep)
		var inst: Node = (load(path) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		for i in range(25):
			await get_tree().process_frame
		if nm == "Shop" and OS.get_environment("SHOP_CONS") != "":
			inst.set("_section", "consumibles")
			inst.call("_render")
			for i in range(15):
				await get_tree().process_frame
			var ssc := inst.get_node("Root/Scroll") as ScrollContainer
			print("SHOP scroll max=", ssc.get_v_scroll_bar().max_value, " page=", ssc.get_v_scroll_bar().page)
		if nm == "Social":
			# Mundo vivo: adelanta el reloj (en memoria, DESPUÉS del
			# load_runtime de la escena) para que haya jornadas jugadas.
			WorldTickEngine.current_epoch_day += 150
			inst.set("_day", WorldTickEngine.current_epoch_day)
			inst.set("_ctx_cache", {})
			inst.set("_feed_mode", "mundo")
			inst.call("_render")
			for i in range(25):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Social_mundo.png"))
			inst.set("_feed_mode", "parati")
			inst.call("_render")
			for i in range(25):
				await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/%s.png" % nm))
		if nm == "PreMatch" and inst.get("_active_tab") != null:
			inst.set("_active_tab", 0)
			inst.call("_refresh_tab_visibility")
			for i in range(10):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/PreMatch_kits.png"))
		if nm == "Shop":
			for v in [["_wardrobe_tab", "chaqueta", "Shop_chaquetas"], ["_wardrobe_tab", "bottom", "Shop_pantalones"], ["_wardrobe_tab", "shoes", "Shop_zapatos"], ["_wardrobe_tab", "feet", "Shop_guayos"], ["_section", "consumibles", "Shop_cons"]]:
				inst.set(v[0], v[1])
				inst.call("_render")
				for i in range(10):
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/%s.png" % v[2]))
			# Probador 3D en vivo: chaqueta puesta, dos fotos para ver que gira
			inst.set("_section", "estilo")
			inst.set("_wardrobe_tab", "chaqueta")
			inst.set("_try_on", "top_bomber")
			inst.call("_render")
			for k in 2:
				await get_tree().create_timer(2.2).timeout
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Shop_probador_%d.png" % k))
		if nm == "Squad" and inst.has_method("_show_squad_list"):
			inst.call("_show_squad_list")
			for i in range(10):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Squad_list.png"))
		if nm == "Match":
			inst.call("_show_team_talk")
			for i in range(40):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Match_talk.png"))
		if nm == "PlayerProfile" and inst.has_method("_on_tab_pressed"):
			inst.call("_on_tab_pressed", "relations")
			for i in range(15):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Profile_relations.png"))
			inst.call("_on_tab_pressed", "showcase")
			for i in range(15):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Profile_showcase.png"))
		if nm == "News":
			var ip := SaveManager.load_player()
			ip.injury_days_remaining = 18
			InjuryDecision.open(inst, ip)
			for i in range(30):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Injury.png"))
		if nm == "Hub":
			var wr := SeasonWrapped.open(inst, {"start_year": 2026, "wrapped": {"matches": 34, "goals": 21, "assists": 9, "avg": 7.34, "level": 18, "partner": "Camila", "chemistry": 72, "position": 2}})
			wr.call("_show", 2)
			for i in range(80):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Wrapped.png"))
			wr.call("_close")
			for i in range(30):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Hub_goals.png"))
			# Habilidades + panel de progreso (v33).
			var pl3 := SaveManager.load_player()
			pl3.skill_points = 6
			pl3.skills = ["st_def1"] if pl3.position == "ST" else []
			SaveManager.save_player(pl3)
			var sk := SkillsPanel.open(inst)
			for i in range(20):
				await get_tree().process_frame
			sk.set("_selected", "st_def2")
			sk.call("_render")
			for i in range(5):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Skills.png"))
			sk.queue_free()
			var lvb: int = pl3.level
			var xpb: int = pl3.career_xp
			var lres: Dictionary = ProgressionEngine.add_xp(pl3, 400)
			var ares: Dictionary = PlayerDevelopment.grant_attribute_xp(pl3, {"shooting": 120.0, "dribbling": 40.0, "speed": 30.0})
			var holder := VBoxContainer.new()
			holder.position = Vector2(20, 160)
			holder.size = Vector2(536, 0)
			holder.custom_minimum_size = Vector2(536, 0)
			var lay := CanvasLayer.new()
			lay.layer = 95
			inst.add_child(lay)
			lay.add_child(holder)
			holder.add_child(ProgressPanel.new().setup(pl3, lvb, xpb, lres, ares))
			for i in range(260):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Progress.png"))
		if nm == "Lifestyle":
			var pl4 := SaveManager.load_player()
			pl4.affinities = {"camila": 46, "lucia": 12, "sofia": 80}
			pl4.mood = 72
			SaveManager.save_player(pl4)
			inst.set("_player", pl4)
			inst.call("_render")
			for i in range(10):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Lifestyle_social.png"))
			var os := OutingScene.open(inst, {"ok": true, "outing": "cine", "with": "camila", "mood": 14, "mental": 10.0, "aff": 18, "met": "", "press": false, "stage_up": "saliendo", "cost": 2})
			for i in range(70):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Outing_cine.png"))
			os.call("_close")
			var os2 := OutingScene.open(inst, {"ok": true, "outing": "fiesta", "with": "", "mood": 16, "mental": 14.0, "aff": 0, "met": "renata", "press": true, "stage_up": "", "cost": 5})
			for i in range(90):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Outing_fiesta.png"))
		if nm == "Awards":
			var me := SaveManager.load_player()
			var fake: Array = []
			for k in range(8):
				fake.append({"name": me.player_name if k == 1 else "Jugador Prueba%d" % k, "club_name": "Club %d" % k, "score": 100 - k * 7, "goals": 20 - k, "assists": 9 - k})
			inst.set("_bd", fake)
			inst.call("_render")
			for i in range(12):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/Awards_podium.png"))
		if nm == "WorldExplorer":
			# Detalle de TU liga: tabla, fixture y la home.
			var lid: int = int(WorldTickEngine.season.get("league_id", -1))
			var lg: LeagueData = null
			for l in WorldTickEngine.world["leagues"]:
				if l.league_id == lid:
					lg = l
			if lg != null:
				inst.call("_on_league_chosen", lg)
				for tab in ["table", "fixtures"]:
					inst.call("_on_league_tab_pressed", tab)
					for i in range(12):
						await get_tree().process_frame
					get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/ui/WE_%s.png" % tab))
		inst.queue_free()
		for i in range(3):
			await get_tree().process_frame
	print("GALERIA OK")
	get_tree().quit(0)
