extends Node
## Fin de temporada con un reporte de prueba (solo en memoria).
func _ready() -> void:
	SaveManager.active_slot_id = "slot_3"
	WorldTickEngine.load_runtime()
	WorldTickEngine.last_season_report = {
		"start_year": 2026, "player_rating": 7.4,
		"player_summary": "34 partidos · 12 goles · 9 asistencias. Titular indiscutido en la segunda vuelta.",
		"club_name": "Atlético Rquena", "club_summary": "3º en LaGiga · Cuartos de final de copa. Clasificó a la Liga Europa.",
		"prize_money": {"total": 850000},
		"ballon_dor": [{"name": "Thiago Rossoni", "club_name": "Real Munták", "goals": 31, "assists": 12},
			{"name": "Samir Ferrán", "club_name": "Unión Caxias", "goals": 22, "assists": 15},
			{"name": "Luca Silvén", "club_name": "Sporting Rquena", "goals": 18, "assists": 20},
			{"name": "Yuki Rossoni", "club_name": "Club Caxias", "goals": 17, "assists": 8}],
	}
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/SeasonCeremony/SeasonCeremony.tscn")
	await get_tree().create_timer(5.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://_pixellab_preview/rev/Ceremony.png"))
	print("CAPTURA ceremonia")
	get_tree().quit()
