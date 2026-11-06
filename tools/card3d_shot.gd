extends Node
## Captura (dev) de la carta con el jugador 3D en el Hub y en Mi Perfil.
## Siembra una carrera en slot_3 (desechable), como ImmersionProbe. Sin --headless:
##   godot --path . --resolution 576x1024 res://tools/Card3DShot.tscn
const WORLD_SEED := 4242

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

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
	WorldTickEngine.season["user_yellow_count"] = 3   # aviso "Amarillas: 3/5"
	SaveManager.save_season(WorldTickEngine.season)
	var pl: PlayerData = SaveManager.load_player()
	pl.fatigue_physical = 72.0
	SaveManager.save_player(pl)
	for scene in ["Hub", "PlayerProfile"]:
		var n: Node = (load("res://scenes/%s/%s.tscn" % [scene, scene]) as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(n)
		await _frames(150)
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://build/card3d_%s.png" % scene))
		n.queue_free()
		await _frames(2)
	print("SHOT OK")
	get_tree().quit()
