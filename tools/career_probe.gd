extends Node
## PRUEBA DE PUNTA A PUNTA (slot_3, copia de prueba en la PC): juega la
## carrera día a día por toda una temporada: simula tus partidos, entra a
## las ofertas, eventos, entrevistas, fin de temporada y renovación.
## Captura cada pantalla nueva y avisa si se traba.
const MAX_MS := 25 * 60 * 1000
var seen: Dictionary = {}
var start_day: int = 0
var last_key: String = ""
var same: int = 0
var matches: int = 0

func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	Preferences.confirm_advance = false
	LiveBridge.test_auto = true
	start_day = WorldTickEngine.current_epoch_day
	var t0: int = Time.get_ticks_msec()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
	await get_tree().create_timer(1.5).timeout
	var season0: int = int(WorldTickEngine.season.get("season_start_epoch_day", 0))
	while Time.get_ticks_msec() - t0 < MAX_MS:
		await get_tree().create_timer(0.15).timeout
		var cs: Node = get_tree().current_scene
		if cs == null:
			continue
		var sc: String = cs.scene_file_path.get_file().get_basename()
		var key: String = "%s@%d" % [sc, WorldTickEngine.current_epoch_day]
		same = same + 1 if key == last_key else 0
		last_key = key
		if same > 60:
			print("CARRERA TRABADA en ", sc, " día ", WorldTickEngine.current_epoch_day)
			await _shot("TRABA_" + sc)
			break
		if not seen.has(sc):
			seen[sc] = true
			print("CARRERA pantalla nueva: ", sc, " (día ", WorldTickEngine.current_epoch_day - start_day, ")")
			await get_tree().create_timer(0.8).timeout
			await _shot("CAR_" + sc)
		match sc:
			"Hub":
				if int(WorldTickEngine.season.get("season_start_epoch_day", 0)) != season0 and WorldTickEngine.current_epoch_day - start_day > 30:
					print("CARRERA temporada nueva alcanzada, día ", WorldTickEngine.current_epoch_day - start_day)
					await _shot("CAR_Hub_temporada2")
					break
				for bn in ["SponsorButton", "WageOfferButton", "SeasonEventButton"]:
					var b: Button = cs.find_child(bn, true, false)
					if b != null and b.visible and not seen.has("btn_" + bn):
						seen["btn_" + bn] = true
						b.pressed.emit()
						continue
				if not cs._pending_fixture.is_empty():
					matches += 1
					cs._try_launch(true)
					await get_tree().create_timer(0.5).timeout
				else:
					WorldTickEngine.advance_day()
			"MatchSummary", "NationalMatchSummary":
				cs._on_continue_pressed()
			"PostMatchInterview":
				var opts: Array = cs.find_children("*", "Button", true, false)
				if not opts.is_empty():
					(opts[0] as Button).pressed.emit()
			"SponsorOffer", "WageOffer":
				cs._on_accept_pressed()
			"SeasonEvent":
				cs._on_option_pressed(0)
			"NationalCallUp":
				cs._on_dismiss_pressed()
			"SeasonCeremony":
				await get_tree().create_timer(1.0).timeout
				cs._on_continue_pressed()
			"Awards":
				cs._on_back_pressed()
			"ContractDecision":
				var ren: Dictionary = WorldTickEngine.season.get("renewal_offer", {})
				var offers: Array = WorldTickEngine.season.get("transfer_offers", [])
				if not ren.is_empty():
					cs._on_option_chosen(String(ren.get("club_id", "")), int(ren.get("wage", 0)))
				elif not offers.is_empty():
					cs._on_option_chosen(String(offers[0].get("club_id", "")), int(offers[0].get("wage", 0)))
				else:
					print("CARRERA sin ofertas: retiro")
					break
			"SeasonLoading", "Retirement":
				pass
			_:
				print("CARRERA pantalla sin manejar: ", sc)
				get_tree().change_scene_to_file("res://scenes/Hub/Hub.tscn")
	print("CARRERA FIN días=%d partidos=%d pantallas=%s" % [WorldTickEngine.current_epoch_day - start_day, matches, ",".join(seen.keys())])
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/car/%s.png" % n))
